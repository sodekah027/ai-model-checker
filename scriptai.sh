#!/bin/sh
# shellcheck disable=all
if [ -z "$BASH_VERSION" ]; then
    if [ -x "/data/data/com.termux/files/usr/bin/bash" ]; then
        exec /data/data/com.termux/files/usr/bin/bash "$0" "$@"
    elif command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    else
        echo "[ERROR] Bash diperlukan untuk menjalankan script ini." >&2
        exit 1
    fi
fi

# ==============================================================================
# Script Name : scriptai.sh
# Deskripsi   : Script interaktif untuk mengecek & mengetes model AI (OpenAI Compatible)
# Penggunaan  : ./scriptai.sh
# ==============================================================================

# Warna Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# File Konfigurasi & Output
CONFIG_FILE="${HOME}/.scriptai.conf"
OUT_SUCCESS="model_aktif.txt"
OUT_REPORT="laporan_test_model.txt"
OUT_HISTORY="riwayat_test.txt"

# Default Variabel
BASE_URL=""
API_KEY=""
TEST_MSG="hai"
TIMEOUT_SEC=15

# Cek dependensi (curl dan jq)
check_dependencies() {
    local missing=()
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v jq >/dev/null 2>&1 || missing+=("jq")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}[ERROR] Aplikasi pendukung belum terpasang: ${missing[*]}${NC}"
        echo -e "Silakan install terlebih dahulu:"
        if command -v pkg >/dev/null 2>&1; then
            echo -e "  ${YELLOW}pkg update && pkg install ${missing[*]} -y${NC}"
        elif command -v apt-get >/dev/null 2>&1; then
            echo -e "  ${YELLOW}sudo apt update && sudo apt install ${missing[*]} -y${NC}"
        fi
        exit 1
    fi
}

# Muat konfigurasi tersimpan
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE" 2>/dev/null || true
    fi
}

# Simpan konfigurasi
save_config() {
    cat <<EOF > "$CONFIG_FILE"
BASE_URL="$BASE_URL"
API_KEY="$API_KEY"
TEST_MSG="$TEST_MSG"
TIMEOUT_SEC=$TIMEOUT_SEC
EOF
}

# Normalisasi URL
clean_url() {
    local url="$1"
    # Trim spasi
    url="${url#"${url%%[![:space:]]*}"}"
    url="${url%"${url##*[![:space:]]}"}"
    # Hapus trailing slash
    while [[ "$url" == */ ]]; do
        url="${url%/}"
    done
    # Tambah https:// jika belum ada skema http/https
    if [[ "$url" != http://* ]] && [[ "$url" != https://* ]]; then
        url="https://$url"
    fi
    echo "$url"
}

# Tampilkan token apa adanya (tanpa sensor)
mask_token() {
    local token="$1"
    if [ -z "$token" ]; then
        echo "(belum diisi)"
    else
        echo "$token"
    fi
}

# Input Base URL
input_base_url() {
    echo -e "\n${BOLD}${CYAN}--- Atur Base URL ---${NC}"
    echo -e "Contoh URL:"
    echo -e "  • ${YELLOW}https://api.openai.com/v1${NC}"
    echo -e "  • ${YELLOW}https://openrouter.ai/api/v1${NC}"
    echo -e "  • ${YELLOW}https://api.deepseek.com/v1${NC}"
    echo -e "  • ${YELLOW}http://localhost:11434/v1${NC}"
    echo ""
    if [ -n "$BASE_URL" ]; then
        echo -e "Base URL saat ini: ${GREEN}$BASE_URL${NC}"
        read -r -p "Masukkan Base URL baru [tekan Enter jika tetap]: " input_url
    else
        read -r -p "Masukkan Base URL: " input_url
    fi

    if [ -n "$input_url" ]; then
        BASE_URL=$(clean_url "$input_url")
        save_config
        echo -e "${GREEN}[OK] Base URL berhasil disetel ke: $BASE_URL${NC}"
    fi
}

# Input Token / API Key
input_token() {
    echo -e "\n${BOLD}${CYAN}--- Atur Token / API Key ---${NC}"
    if [ -n "$API_KEY" ]; then
        echo -e "Token saat ini : ${GREEN}$(mask_token "$API_KEY")${NC}"
        read -r -p "Masukkan Token/Key baru [tekan Enter jika tetap]: " input_key
    else
        read -r -p "Masukkan Token/Key: " input_key
    fi

    if [ -n "$input_key" ]; then
        # Trim spasi
        input_key="${input_key#"${input_key%%[![:space:]]*}"}"
        input_key="${input_key%"${input_key##*[![:space:]]}"}"
        API_KEY="$input_key"
        save_config
        echo -e "${GREEN}[OK] Token berhasil disimpan: $(mask_token "$API_KEY")${NC}"
    fi
}

# Input Pesan Uji Coba Chat
input_test_msg() {
    echo -e "\n${BOLD}${CYAN}--- Atur Pesan Test Chat ---${NC}"
    echo -e "Pesan saat ini : \"${YELLOW}$TEST_MSG${NC}\""
    read -r -p "Masukkan pesan tes baru [tekan Enter jika tetap]: " new_msg
    if [ -n "$new_msg" ]; then
        TEST_MSG="$new_msg"
        save_config
        echo -e "${GREEN}[OK] Pesan tes diubah menjadi: \"$TEST_MSG\"${NC}"
    fi
}

# Mengambil list model dari endpoint /models
fetch_models() {
    local target_url="$1"
    local token="$2"

    local tmp_resp
    tmp_resp=$(mktemp)

    local http_code
    http_code=$(curl -s -m "$TIMEOUT_SEC" -w "%{http_code}" -o "$tmp_resp" \
        -H "Authorization: Bearer $token" \
        -H "Accept: application/json" \
        -H "HTTP-Referer: https://github.com" \
        -H "X-Title: AI-Model-Checker" \
        "${target_url}/models" 2>/dev/null)

    # Jika 404 dan URL belum ada /v1, coba otomatis ${target_url}/v1/models
    if [ "$http_code" = "404" ] && [[ "$target_url" != *"/v1" ]]; then
        local retry_url="${target_url}/v1"
        local retry_code
        retry_code=$(curl -s -m "$TIMEOUT_SEC" -w "%{http_code}" -o "$tmp_resp" \
            -H "Authorization: Bearer $token" \
            -H "Accept: application/json" \
            "${retry_url}/models" 2>/dev/null)
        if [ "$retry_code" = "200" ]; then
            BASE_URL="$retry_url"
            save_config
            target_url="$retry_url"
            http_code="$retry_code"
        fi
    fi

    local resp_content
    resp_content=$(cat "$tmp_resp")
    rm -f "$tmp_resp"

    if [ "$http_code" != "200" ]; then
        echo -e "${RED}[ERROR] Gagal memuat daftar model (HTTP $http_code)${NC}"
        local err_detail
        err_detail=$(echo "$resp_content" | jq -r '(.error.message // .error // .message // empty)' 2>/dev/null)
        if [ -n "$err_detail" ]; then
            echo -e "${RED}Pesan Error : $err_detail${NC}"
        elif [ "$http_code" = "000" ]; then
            echo -e "${RED}Penyebab    : Koneksi timeout atau domain Base URL tidak dapat diakses.${NC}"
        elif [ "$http_code" = "401" ]; then
            echo -e "${RED}Penyebab    : Token / API Key salah atau tidak memiliki izin.${NC}"
        elif [ "$http_code" = "404" ]; then
            echo -e "${RED}Penyebab    : Endpoint /models tidak ditemukan. Pastikan Base URL benar.${NC}"
        fi
        return 1
    fi

    # Parsing list model secara adaptif
    local model_list
    model_list=$(echo "$resp_content" | jq -r '
      if .data? and (.data | type == "array") then
        .data[] | if type == "object" then .id else . end
      elif .models? and (.models | type == "array") then
        .models[] | if type == "object" then (.name // .id) else . end
      elif type == "array" then
        .[] | if type == "object" then .id else . end
      else
        empty
      end
    ' 2>/dev/null)

    if [ -z "$model_list" ]; then
        echo -e "${YELLOW}[!] Endpoint merespon 200 OK, tetapi tidak ditemukan item model pada format JSON.${NC}"
        return 1
    fi

    echo "$model_list"
    return 0
}

# Kirim chat completion untuk 1 model
test_single_model() {
    local model="$1"
    local message="$2"
    local base="$3"
    local token="$4"

    local endpoint="${base}/chat/completions"
    local payload
    payload=$(jq -nc --arg m "$model" --arg msg "$message" \
        '{"model": $m, "messages": [{"role": "user", "content": $msg}], "max_tokens": 20}')

    local tmp_out
    tmp_out=$(mktemp)

    local stats
    stats=$(curl -s -m "$TIMEOUT_SEC" -w "%{http_code} %{time_total}" -o "$tmp_out" \
        -X POST "$endpoint" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -H "HTTP-Referer: https://github.com" \
        -H "X-Title: AI-Model-Checker" \
        -d "$payload" 2>/dev/null)

    local http_code
    http_code=$(echo "$stats" | awk '{print $1}')
    local time_sec
    time_sec=$(echo "$stats" | awk '{print $2}')
    local body
    body=$(cat "$tmp_out")
    rm -f "$tmp_out"

    # Jika model membutuhkan max_completion_tokens (misal o1 / o3)
    local err_check
    err_check=$(echo "$body" | jq -r '(.error.message // .error // empty)' 2>/dev/null)
    if [[ "$err_check" == *"max_completion_tokens"* ]]; then
        payload=$(jq -nc --arg m "$model" --arg msg "$message" \
            '{"model": $m, "messages": [{"role": "user", "content": $msg}], "max_completion_tokens": 20}')
        tmp_out=$(mktemp)
        stats=$(curl -s -m "$TIMEOUT_SEC" -w "%{http_code} %{time_total}" -o "$tmp_out" \
            -X POST "$endpoint" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            -d "$payload" 2>/dev/null)
        http_code=$(echo "$stats" | awk '{print $1}')
        time_sec=$(echo "$stats" | awk '{print $2}')
        body=$(cat "$tmp_out")
        rm -f "$tmp_out"
    fi

    # Format waktu ke 2 desimal
    local time_disp
    time_disp=$(awk -v t="$time_sec" 'BEGIN {printf "%.2fs", t}')

    if [ "$http_code" = "200" ]; then
        local reply
        reply=$(echo "$body" | jq -r '(.choices[0].message.content // .choices[0].message.reasoning_content // .choices[0].text // .choices[0].delta.content // empty)' 2>/dev/null)
        if [ -z "$reply" ]; then
            reply="(200 OK - Respon diterima)"
        else
            reply=$(echo "$reply" | tr '\n\r' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
            if [ ${#reply} -gt 60 ]; then
                reply="${reply:0:57}..."
            fi
        fi
        echo "SUCCESS|${time_disp}|${reply}"
    else
        local reason
        reason=$(echo "$body" | jq -r '(.error.message // .error // .message // empty)' 2>/dev/null)
        if [ -z "$reason" ]; then
            if [ "$http_code" = "000" ]; then
                reason="Timeout / Tidak merespon (> ${TIMEOUT_SEC}s)"
            else
                reason="HTTP $http_code"
            fi
        fi
        reason=$(echo "$reason" | tr '\n\r' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
        if [ ${#reason} -gt 65 ]; then
            reason="${reason:0:62}..."
        fi
        echo "FAILED|${http_code}|${reason}"
    fi
}

# Alur Utama Pengetesan Model
run_model_test() {
    # Cek kelengkapan kredensial
    if [ -z "$BASE_URL" ]; then
        input_base_url
    fi
    if [ -z "$API_KEY" ]; then
        input_token
    fi

    if [ -z "$BASE_URL" ] || [ -z "$API_KEY" ]; then
        echo -e "\n${RED}[!] Base URL dan Token wajib diisi terlebih dahulu.${NC}"
        read -r -p "Tekan [Enter] untuk kembali..."
        return
    fi

    echo -e "\n${BOLD}${CYAN}========================================================${NC}"
    echo -e "${BOLD}${CYAN}              MEMULAI PROSES PENGECEKAN                 ${NC}"
    echo -e "${BOLD}${CYAN}========================================================${NC}"
    echo -e " Base URL  : ${GREEN}$BASE_URL${NC}"
    echo -e " Token     : ${GREEN}$(mask_token "$API_KEY")${NC}"
    echo -e " Pesan Tes : \"${YELLOW}$TEST_MSG${NC}\""
    echo -e " Timeout   : ${TIMEOUT_SEC} detik"
    echo -e "--------------------------------------------------------"
    echo -e "${YELLOW}[*] Menghubungi $BASE_URL/models ...${NC}"

    local raw_models
    raw_models=$(fetch_models "$BASE_URL" "$API_KEY")
    local fetch_status=$?

    if [ $fetch_status -ne 0 ] || [ -z "$raw_models" ]; then
        read -r -p "Tekan [Enter] untuk kembali ke menu..."
        return
    fi

    mapfile -t model_list <<< "$raw_models"
    local total_models=${#model_list[@]}

    echo -e "${GREEN}[✓] Sukses! Ditemukan ${BOLD}$total_models model${NC}${GREEN}.${NC}\n"

    echo -e "Pilihan pengujian:"
    echo -e "  [Enter] / [A] : Test SEMUA model ($total_models model)"
    echo -e "  [Angka]       : Batasi jumlah (misal ketik 5 untuk 5 model teratas)"
    echo -e "  [C]           : Batalkan dan kembali ke menu"
    read -r -p "Pilihan Anda: " run_choice

    if [[ "$run_choice" =~ ^[Cc]$ ]]; then
        echo -e "${YELLOW}Pengetesan dibatalkan.${NC}"
        read -r -p "Tekan [Enter] untuk kembali..."
        return
    fi

    local max_to_test=$total_models
    if [[ "$run_choice" =~ ^[0-9]+$ ]] && [ "$run_choice" -gt 0 ] && [ "$run_choice" -le "$total_models" ]; then
        max_to_test=$run_choice
    fi

    echo ""
    echo -e "${BOLD}Sedang mengetes $max_to_test model dengan pesan: \"$TEST_MSG\" ...${NC}"
    echo -e "${CYAN}(Tekan Ctrl+C untuk menghentikan tes dan melihat ringkasan)${NC}"
    echo -e "--------------------------------------------------------------------------------"

    # Reset file hasil
    > "$OUT_SUCCESS"
    {
        echo "========================================================="
        echo "LAPORAN PENGETESAN MODEL AI"
        echo "Waktu   : $(date)"
        echo "Base URL: $BASE_URL"
        echo "Pesan   : $TEST_MSG"
        echo "========================================================="
        echo ""
    } > "$OUT_REPORT"

    local count_success=0
    local count_failed=0
    local current_idx=0

    # Trap Ctrl+C agar berhenti secara teratur
    local interrupted=0
    trap 'interrupted=1; echo -e "\n${YELLOW}[!] Menghentikan proses pengujian...${NC}"' INT

    for model in "${model_list[@]}"; do
        if [ "$interrupted" -eq 1 ]; then
            break
        fi

        current_idx=$((current_idx + 1))
        if [ "$current_idx" -gt "$max_to_test" ]; then
            break
        fi

        printf "${CYAN}[%d/%d]${NC} %-35s " "$current_idx" "$max_to_test" "$model"

        local res
        res=$(test_single_model "$model" "$TEST_MSG" "$BASE_URL" "$API_KEY")
        local status
        status=$(echo "$res" | cut -d'|' -f1)
        local param2
        param2=$(echo "$res" | cut -d'|' -f2)
        local param3
        param3=$(echo "$res" | cut -d'|' -f3-)

        if [ "$status" = "SUCCESS" ]; then
            count_success=$((count_success + 1))
            echo -e "${GREEN}[✓ BERHASIL]${NC} (${param2}) -> \"${param3}\""
            echo "$model" >> "$OUT_SUCCESS"
            echo "[SUKSES] $model | Waktu: $param2 | Respon: $param3" >> "$OUT_REPORT"
        else
            count_failed=$((count_failed + 1))
            echo -e "${RED}[✗ GAGAL]${NC} (${param2}) -> ${YELLOW}${param3}${NC}"
            echo "[GAGAL]  $model | HTTP: $param2 | Detail: $param3" >> "$OUT_REPORT"
        fi
    done

    trap - INT

    # Simpan riwayat per-run (append, tidak menimpa riwayat provider lain)
    {
        echo ""
        echo "========================================================="
        echo "WAKTU          : $(date '+%d-%m-%Y %H:%M:%S')"
        echo "BASE URL       : $BASE_URL"
        echo "TOKEN          : $API_KEY"
        echo "HASIL          : $count_success sukses / $count_failed gagal"
        if [ "$count_success" -gt 0 ]; then
            echo "MODEL WORK     :"
            sed 's/^/  - /' "$OUT_SUCCESS"
        else
            echo "MODEL WORK     : (tidak ada)"
        fi
        echo "========================================================="
    } >> "$OUT_HISTORY"

    echo -e "--------------------------------------------------------------------------------"
    echo -e "${BOLD}${CYAN}=== RINGKASAN HASIL PENGUJIAN ===${NC}"
    echo -e "Total Dites    : ${BOLD}$((count_success + count_failed))${NC}"
    echo -e "Berhasil (Aktif): ${GREEN}${BOLD}$count_success${NC}"
    echo -e "Gagal          : ${RED}${BOLD}$count_failed${NC}"
    echo -e "Model Aktif    : Disimpan ke file ${YELLOW}$OUT_SUCCESS${NC}"
    echo -e "Laporan Detail : Disimpan ke file ${YELLOW}$OUT_REPORT${NC}"
    echo -e "Riwayat Semua Provider : Disimpan ke file ${YELLOW}$OUT_HISTORY${NC}"
    echo -e "--------------------------------------------------------------------------------"
    read -r -p "Tekan [Enter] untuk kembali ke menu utama..."
}

# Test 1 Model Tertentu Secara Manual
test_manual_model() {
    if [ -z "$BASE_URL" ]; then input_base_url; fi
    if [ -z "$API_KEY" ]; then input_token; fi

    if [ -z "$BASE_URL" ] || [ -z "$API_KEY" ]; then
        echo -e "${RED}[!] Base URL dan Token wajib diisi.${NC}"
        read -r -p "Tekan [Enter] untuk kembali..."
        return
    fi

    echo -e "\n${BOLD}${CYAN}--- Test 1 Model Secara Manual ---${NC}"
    read -r -p "Masukkan nama ID model (contoh: gpt-4o-mini): " target_model
    if [ -z "$target_model" ]; then
        echo -e "${YELLOW}Dibatalkan.${NC}"
        read -r -p "Tekan [Enter] untuk kembali..."
        return
    fi

    echo -e "\n${YELLOW}[*] Mengetes model: ${BOLD}$target_model${NC} ${YELLOW}dengan pesan: \"$TEST_MSG\" ...${NC}"
    local res
    res=$(test_single_model "$target_model" "$TEST_MSG" "$BASE_URL" "$API_KEY")
    local status
    status=$(echo "$res" | cut -d'|' -f1)
    local param2
    param2=$(echo "$res" | cut -d'|' -f2)
    local param3
    param3=$(echo "$res" | cut -d'|' -f3-)

    echo "--------------------------------------------------------"
    if [ "$status" = "SUCCESS" ]; then
        echo -e "Status   : ${GREEN}${BOLD}BERHASIL (HTTP 200)${NC}"
        echo -e "Latensi  : ${GREEN}$param2${NC}"
        echo -e "Respon   : \"${GREEN}$param3${NC}\""
    else
        echo -e "Status   : ${RED}${BOLD}GAGAL${NC}"
        echo -e "HTTP Code: ${RED}$param2${NC}"
        echo -e "Pesan    : ${YELLOW}$param3${NC}"
    fi
    echo "--------------------------------------------------------"
    read -r -p "Tekan [Enter] untuk kembali..."
}

# Menu Lihat Daftar Model Saja
view_model_list_only() {
    if [ -z "$BASE_URL" ]; then input_base_url; fi
    if [ -z "$API_KEY" ]; then input_token; fi

    if [ -z "$BASE_URL" ] || [ -z "$API_KEY" ]; then
        echo -e "${RED}[!] Base URL dan Token wajib diisi.${NC}"
        read -r -p "Tekan [Enter] untuk kembali..."
        return
    fi

    echo -e "\n${YELLOW}[*] Mengambil daftar model dari $BASE_URL/models ...${NC}"
    local raw_models
    raw_models=$(fetch_models "$BASE_URL" "$API_KEY")
    if [ $? -ne 0 ] || [ -z "$raw_models" ]; then
        read -r -p "Tekan [Enter] untuk kembali..."
        return
    fi

    mapfile -t model_list <<< "$raw_models"
    local total=${#model_list[@]}

    echo -e "\n${GREEN}${BOLD}Ditemukan $total Model:${NC}"
    echo -e "--------------------------------------------------------"
    local i=1
    for m in "${model_list[@]}"; do
        printf "%3d. %s\n" "$i" "$m"
        i=$((i + 1))
    done
    echo -e "--------------------------------------------------------"
    read -r -p "Tekan [Enter] untuk kembali..."
}

# Menu Lihat Hasil Model Aktif Sebelumnya
view_saved_success() {
    if [ ! -f "$OUT_SUCCESS" ] || [ ! -s "$OUT_SUCCESS" ]; then
        echo -e "\n${YELLOW}[!] Belum ada riwayat model aktif. Jalankan test model terlebih dahulu.${NC}"
    else
        local count
        count=$(wc -l < "$OUT_SUCCESS")
        echo -e "\n${GREEN}${BOLD}Daftar Model Aktif Terakhir ($count model):${NC}"
        echo -e "--------------------------------------------------------"
        cat -n "$OUT_SUCCESS"
        echo -e "--------------------------------------------------------"
    fi
    read -r -p "Tekan [Enter] untuk kembali..."
}

# Menu Lihat Riwayat Semua Provider
view_history() {
    if [ ! -f "$OUT_HISTORY" ] || [ ! -s "$OUT_HISTORY" ]; then
        echo -e "\n${YELLOW}[!] Belum ada riwayat. Jalankan test model terlebih dahulu.${NC}"
    else
        echo -e "\n${GREEN}${BOLD}Riwayat Pengetesan Semua Provider:${NC}"
        echo -e "--------------------------------------------------------"
        cat "$OUT_HISTORY"
        echo -e "--------------------------------------------------------"
        echo -e "File riwayat: ${YELLOW}$OUT_HISTORY${NC}"
    fi
    read -r -p "Tekan [Enter] untuk kembali..."
}

# Tampilan Menu Utama
main_menu() {
    check_dependencies
    load_config

    while true; do
        clear
        echo -e "${BOLD}${CYAN}========================================================${NC}"
        echo -e "${BOLD}${CYAN}        AI MODEL TESTER & CHECKER (Bash Script)         ${NC}"
        echo -e "${BOLD}${CYAN}========================================================${NC}"
        if [ -n "$BASE_URL" ]; then
            echo -e " Base URL  : ${GREEN}$BASE_URL${NC}"
        else
            echo -e " Base URL  : ${RED}(belum diisi)${NC}"
        fi

        if [ -n "$API_KEY" ]; then
            echo -e " Token/Key : ${GREEN}$(mask_token "$API_KEY")${NC}"
        else
            echo -e " Token/Key : ${RED}(belum diisi)${NC}"
        fi
        echo -e " Pesan Tes : \"${YELLOW}$TEST_MSG${NC}\""
        echo -e "${BOLD}${CYAN}========================================================${NC}"
        echo -e " [1] ${BOLD}Mulai Test Semua Model${NC} (Auto Base URL -> Token -> Test)"
        echo -e " [2] Test 1 Model Tertentu (Ketik nama model manual)"
        echo -e " [3] Atur / Ganti Base URL"
        echo -e " [4] Atur / Ganti Token / API Key"
        echo -e " [5] Atur Pesan Chat Test (Default: \"$TEST_MSG\")"
        echo -e " [6] Lihat Daftar Model Saja (Tanpa Chat)"
        echo -e " [7] Lihat Daftar Model yang Sukses Sebelumnya"
        echo -e " [8] Lihat Riwayat Semua Provider (Base URL + Token + Model Work)"
        echo -e " [0] Keluar"
        echo -e "${BOLD}${CYAN}========================================================${NC}"
        read -r -p "Pilih menu [0-8]: " choice

        case "$choice" in
            1) run_model_test ;;
            2) test_manual_model ;;
            3) input_base_url; read -r -p "Tekan [Enter] untuk melanjutkan..." ;;
            4) input_token; read -r -p "Tekan [Enter] untuk melanjutkan..." ;;
            5) input_test_msg; read -r -p "Tekan [Enter] untuk melanjutkan..." ;;
            6) view_model_list_only ;;
            7) view_saved_success ;;
            8) view_history ;;
            0|q|Q)
                echo -e "\n${GREEN}Selesai. Terima kasih!${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}Pilihan tidak valid!${NC}"
                sleep 1
                ;;
        esac
    done
}

# Jalankan Menu Utama
main_menu
