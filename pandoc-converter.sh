#!/bin/bash

# pandoc kontrol
if ! command -v pandoc &> /dev/null; then
    echo "HATA: pandoc yüklü değil"
    echo "Yüklemek için: sudo apt install pandoc"
    exit 1
fi

# UI tipi seçimi
choose_ui() {
    has_yad=$(command -v yad &> /dev/null && echo 1 || echo 0)
    has_whiptail=$(command -v whiptail &> /dev/null && echo 1 || echo 0)
    
    if [ $has_yad -eq 0 ] && [ $has_whiptail -eq 0 ]; then
        echo "HATA: Grafik arayüz bulunamadı!"
        echo "Yüklemek için:"
        echo "  sudo apt install yad"
        echo "  veya"
        echo "  sudo apt install whiptail"
        exit 1
    fi
    
    if [ $has_yad -eq 1 ] && [ $has_whiptail -eq 1 ]; then
        # arayüz seçimi
        choice=$(whiptail --title "Arayüz Seçimi" --menu "Hangi arayüzü kullanmak istersiniz?" 15 60 2 \
            "1" "YAD (Grafik)" \
            "2" "Whiptail (Terminal)" \
            3>&1 1>&2 2>&3)
        
        case $choice in
            1) echo "yad" ;;
            2) echo "whiptail" ;;
            *) echo "whiptail" ;;
        esac
    elif [ $has_yad -eq 1 ]; then
        echo "yad"
    else
        echo "whiptail"
    fi
}

UI_TYPE=$(choose_ui)
ICON_PATH="/usr/share/icons/hicolor/48x48/apps"
WINDOW_ICON="text-x-generic"

# ANA MENÜ

show_main_menu() {
    if [ "$UI_TYPE" = "yad" ]; then
        show_main_menu_yad
    else
        show_main_menu_whiptail
    fi
}

show_main_menu_yad() {
    choice=$(yad --list \
        --title="Pandoc Dönüştürücü" \
        --window-icon="$WINDOW_ICON" \
        --width=500 --height=350 \
        --column="Seçenek" --column="Açıklama" \
        --text="Belge formatları arası dönüştürme aracı" \
        --button="Çıkış:1" \
        --button="Seç:0" \
        "1" "Markdown to PDF" \
        "2" "Markdown to DOCX" \
        "3" "Markdown to HTML" \
        "4" "HTML to Markdown" \
        "5" "DOCX to Markdown" \
        "6" "PDF to Markdown" \
        2>/dev/null)
    
    ret=$?
    [ $ret -eq 1 ] || [ -z "$choice" ] && exit 0 # iptal veya boş seçimde çıkma
    
    selection=$(echo "$choice" | cut -d'|' -f1)
    
    case "$selection" in
        1) convert_md_to_pdf ;;
        2) convert_md_to_docx ;;
        3) convert_md_to_html ;;
        4) convert_html_to_md ;;
        5) convert_docx_to_md ;;
        6) convert_pdf_to_md ;;
        *) show_main_menu ;;
    esac
}

show_main_menu_whiptail() {
    choice=$(whiptail --title "Pandoc Dönüştürücü" --menu "Format dönüştürme seçin:" 18 60 8 \
        "1" "Markdown to PDF" \
        "2" "Markdown to DOCX" \
        "3" "Markdown to HTML" \
        "4" "HTML to Markdown" \
        "5" "DOCX to Markdown" \
        "6" "PDF to Markdown" \
        "7" "Çıkış" \
        3>&1 1>&2 2>&3)
    
    case $choice in
        1) convert_md_to_pdf ;;
        2) convert_md_to_docx ;;
        3) convert_md_to_html ;;
        4) convert_html_to_md ;;
        5) convert_docx_to_md ;;
        6) convert_pdf_to_md ;;
        7) exit 0 ;;
        *) exit 0 ;;
    esac
}

# DOSYA SEÇİM FONKSİYONLARI
# seçilecek dosya
select_file() {
    local filter=$1 # örn: *.md
    local title=$2 # pencere başlığı
    
    if [ "$UI_TYPE" = "yad" ]; then
        yad --file --title="$title" --file-filter="$filter" --width=600 --height=400 2>/dev/null
    else
        # whiptail için dosya yolu girişi
        default=$(echo "$filter" | sed 's/\*\.//;s/ .*//')
        path=$(whiptail --title "$title" --inputbox "Dosya yolu girin:" 10 60 "dosya.$default" 3>&1 1>&2 2>&3)
        
        if [ -z "$path" ] || [ ! -f "$path" ]; then
            [ -n "$path" ] && whiptail --title "Hata" --msgbox "Dosya bulunamadı: $path" 8 60
            return 1
        fi
        
        echo "$path"
    fi
}
# kaydedilecek alan
select_save_location() {
    local default_name=$1
    
    if [ "$UI_TYPE" = "yad" ]; then
        yad --file --save --title="Kayıt Yeri" --filename="$default_name" --width=600 --height=400 2>/dev/null
    else
        path=$(whiptail --title "Kayıt Yeri" --inputbox "Çıktı dosya yolu:" 10 60 "$default_name" 3>&1 1>&2 2>&3)
        
        if [ -z "$path" ]; then
            return 1
        fi
        
        echo "$path"
    fi
}

# MESAJ FONKSİYONLARI

show_info() {
    local message=$1
    
    if [ "$UI_TYPE" = "yad" ]; then
        yad --info --text="$message" --width=300 --window-icon="$WINDOW_ICON" 2>/dev/null
    else
        whiptail --title "Bilgi" --msgbox "$message" 10 60
    fi
}

show_error() {
    local message=$1
    
    if [ "$UI_TYPE" = "yad" ]; then
        yad --error --text="$message" --width=300 --window-icon="$WINDOW_ICON" 2>/dev/null
    else
        whiptail --title "Hata" --msgbox "$message" 10 60
    fi
}

# MARKDOWN to PDF
convert_md_to_pdf() {
    input_file=$(select_file "*.md *.markdown" "Markdown Dosyası Seç")
    
    if [ -z "$input_file" ]; then
        show_main_menu
        return
    fi
    
    base_name=$(basename "$input_file" | sed 's/\.[^.]*$//')
    output_file=$(select_save_location "${base_name}.pdf")
    
    if [ -z "$output_file" ]; then
        show_main_menu
        return
    fi
    
    # PDF ayarları
    if [ "$UI_TYPE" = "yad" ]; then
        engine=$(yad --form \
            --title="PDF Ayarları" \
            --window-icon="$WINDOW_ICON" \
            --width=400 \
            --field="PDF Motoru:CB" "pdflatex!xelatex!lualatex" \
            --field="Sayfa Boyutu:CB" "a4paper!letterpaper" \
            --field="İçindekiler:CHK" "FALSE" \
            --button="İptal:1" \
            --button="Dönüştür:0" \
            2>/dev/null)
        
        [ $? -eq 1 ] && { show_main_menu; return; }
        
        pdf_engine=$(echo "$engine" | cut -d'|' -f1)
        page_size=$(echo "$engine" | cut -d'|' -f2)
        toc=$(echo "$engine" | cut -d'|' -f3)
        toc_flag=""
        [ "$toc" = "TRUE" ] && toc_flag="--toc"
    else
        pdf_engine=$(whiptail --title "PDF Motoru" --menu "PDF motoru seçin:" 15 50 3 \
            "pdflatex" "Varsayılan LaTeX" \
            "xelatex" "Unicode desteği" \
            "lualatex" "Lua entegrasyonu" \
            3>&1 1>&2 2>&3)
        
        [ -z "$pdf_engine" ] && { show_main_menu; return; }
        
        page_size="a4paper"
        toc_flag=""
        whiptail --title "İçindekiler" --yesno "İçindekiler tablosu eklensin mi?" 8 50 && toc_flag="--toc"
    fi
    
    # dönüştürme işlemi 
    if pandoc "$input_file" -o "$output_file" --pdf-engine=$pdf_engine -V geometry:$page_size $toc_flag 2>/tmp/pandoc_error.log; then
        show_info "Dönüştürme başarılı!\n\n$output_file"
    else
        error_msg=$(cat /tmp/pandoc_error.log 2>/dev/null | head -n 5)
        show_error "Dönüştürme başarısız!\n\n$error_msg"
    fi
    
    show_main_menu
}

# MARKDOWN to DOCX
convert_md_to_docx() {
    input_file=$(select_file "*.md *.markdown" "Markdown Dosyası Seç")
    
    if [ -z "$input_file" ]; then
        show_main_menu
        return
    fi
    
    base_name=$(basename "$input_file" | sed 's/\.[^.]*$//')
    output_file=$(select_save_location "${base_name}.docx")
    
    if [ -z "$output_file" ]; then
        show_main_menu
        return
    fi
    
    if pandoc "$input_file" -o "$output_file" 2>/tmp/pandoc_error.log; then
        show_info "Dönüştürme başarılı!\n\n$output_file"
    else
        error_msg=$(cat /tmp/pandoc_error.log 2>/dev/null | head -n 5)
        show_error "Dönüştürme başarısız!\n\n$error_msg"
    fi
    
    show_main_menu
}

# MARKDOWN to HTML
convert_md_to_html() {
    input_file=$(select_file "*.md *.markdown" "Markdown Dosyası Seç")
    
    if [ -z "$input_file" ]; then
        show_main_menu
        return
    fi
    
    base_name=$(basename "$input_file" | sed 's/\.[^.]*$//')
    output_file=$(select_save_location "${base_name}.html")
    
    if [ -z "$output_file" ]; then
        show_main_menu
        return
    fi
    
    # HTML seçenekleri
    cmd="pandoc \"$input_file\" -o \"$output_file\""
    
    if [ "$UI_TYPE" = "yad" ]; then
        options=$(yad --form \
            --title="HTML Ayarları" \
            --window-icon="$WINDOW_ICON" \
            --width=400 \
            --field="Standalone (tam html):CHK" "TRUE" \
            --field="CSS ekle:CHK" "FALSE" \
            --field="Syntax highlighting:CHK" "TRUE" \
            --field="İçindekiler:CHK" "FALSE" \
            --button="İptal:1" \
            --button="Dönüştür:0" \
            2>/dev/null)
        
        [ $? -eq 1 ] && { show_main_menu; return; }
        
        standalone=$(echo "$options" | cut -d'|' -f1)
        css=$(echo "$options" | cut -d'|' -f2)
        highlight=$(echo "$options" | cut -d'|' -f3)
        toc=$(echo "$options" | cut -d'|' -f4)
        
        [ "$standalone" = "TRUE" ] && cmd="$cmd --standalone"
        [ "$css" = "TRUE" ] && cmd="$cmd --css=style.css"
        [ "$highlight" = "TRUE" ] && cmd="$cmd --highlight-style=tango"
        [ "$toc" = "TRUE" ] && cmd="$cmd --toc"
    else
        whiptail --title "HTML Formatı" --yesno "Tam HTML belgesi oluşturulsun mu?" 10 50 && cmd="$cmd --standalone"
        whiptail --title "Kod Vurgulama" --yesno "Syntax highlighting eklensin mi?" 8 50 && cmd="$cmd --highlight-style=tango"
    fi
    
    if eval $cmd 2>/tmp/pandoc_error.log; then
        show_info "Dönüştürme başarılı!\n\n$output_file"
    else
        error_msg=$(cat /tmp/pandoc_error.log 2>/dev/null | head -n 5)
        show_error "Dönüştürme başarısız!\n\n$error_msg"
    fi
    
    show_main_menu
}

# HTML to MARKDOWN
convert_html_to_md() {
    input_file=$(select_file "*.html *.htm" "HTML Dosyası Seç")
    
    if [ -z "$input_file" ]; then
        show_main_menu
        return
    fi
    
    base_name=$(basename "$input_file" | sed 's/\.[^.]*$//')
    output_file=$(select_save_location "${base_name}.md")
    
    if [ -z "$output_file" ]; then
        show_main_menu
        return
    fi
    
    if pandoc "$input_file" -o "$output_file" 2>/tmp/pandoc_error.log; then
        show_info "Dönüştürme başarılı!\n\n$output_file"
    else
        error_msg=$(cat /tmp/pandoc_error.log 2>/dev/null | head -n 5)
        show_error "Dönüştürme başarısız!\n\n$error_msg"
    fi
    
    show_main_menu
}

# DOCX to MARKDOWN (görsel ayıklamayla beraber)
convert_docx_to_md() {
    input_file=$(select_file "*.docx" "DOCX Dosyası Seç")
    
    if [ -z "$input_file" ]; then
        show_main_menu
        return
    fi
    
    base_name=$(basename "$input_file" | sed 's/\.[^.]*$//')
    output_file=$(select_save_location "${base_name}.md")
    
    if [ -z "$output_file" ]; then
        show_main_menu
        return
    fi
    
    media_flag=""
    if [ "$UI_TYPE" = "yad" ]; then
        media_flag="--extract-media=./media"
    else
        whiptail --title "Görseller" --yesno "Görseller ./media klasörüne çıkarılsın mı?" 8 50 && media_flag="--extract-media=./media"
    fi
    
    if pandoc "$input_file" -o "$output_file" $media_flag 2>/tmp/pandoc_error.log; then
        msg="Dönüştürme başarılı!\n\n$output_file"
        [ -n "$media_flag" ] && msg="$msg\n\nGörseller ./media klasörüne çıkarıldı"
        show_info "$msg"
    else
        error_msg=$(cat /tmp/pandoc_error.log 2>/dev/null | head -n 5)
        show_error "Dönüştürme başarısız!\n\n$error_msg"
    fi
    
    show_main_menu
}

# PDF to MD
convert_pdf_to_md() {
    # poppler-utils paketinden pdftotext gerektirir.
    if ! command -v pdftotext &> /dev/null; then
        show_error "pdftotext yüklü değil\n\nsudo apt install poppler-utils"
        show_main_menu
        return
    fi
    
    input_file=$(select_file "*.pdf" "PDF Dosyası Seç")
    
    if [ -z "$input_file" ]; then
        show_main_menu
        return
    fi
    
    base_name=$(basename "$input_file" | sed 's/\.[^.]*$//')
    output_file=$(select_save_location "${base_name}.md")
    
    if [ -z "$output_file" ]; then
        show_main_menu
        return
    fi
    
    temp_txt=$(mktemp)
    if pdftotext "$input_file" "$temp_txt" 2>/tmp/pandoc_error.log && \
       pandoc "$temp_txt" -o "$output_file" 2>>/tmp/pandoc_error.log; then
        rm -f "$temp_txt"
        show_info "Dönüştürme başarılı!\n\n$output_file"
    else
        rm -f "$temp_txt"
        error_msg=$(cat /tmp/pandoc_error.log 2>/dev/null | head -n 5)
        show_error "Dönüştürme başarısız!\n\n$error_msg"
    fi
    
    show_main_menu
}

# programı başlatma
show_main_menu