#!/bin/bash

# --- SETTINGS ---
# Array
RECIPIENT_MAIL=(mail@domain1.tld mail@domain2.tld)

# Add allowed emails separated by SPACE.
WHITELIST_EMAILS="whitelistmai1@domain.tld whitelistmai2@domain.tld" 

CSV_FILE="status_admins_wp_$(date +%Y%m%d).csv"
WP_BIN=$(which wp)
LOG_FILE="/var/log/wp_audit.log"
# --------------------------------

# Flag Debug (-d)
DEBUG_MODE=false
while getopts "d" opt; do
  case $opt in
    d) DEBUG_MODE=true ;;
    *) echo "Uso: $0 [-d]"; exit 1 ;;
  esac
done

# Capture Start Time
START_DATE=$(date +"%d-%m-%y")
START_TIME=$(date +"%H:%M:%S")

# Detect System Language
SYSTEM_LANG="${LANG:0:2}"

if [[ "$SYSTEM_LANG" == "pt" ]]; then
    MSG_START="Iniciando auditoria inteligente em"
    MSG_ACCOUNTS="contas"
    MSG_IGNORE="Ignorando admins listados na Whitelist..."
    MSG_PROC="Processando"
    MSG_DONE="Processo Concluído"
    MSG_SAVED="Relatório salvo em"
    MSG_SENDING="Enviando relatório para"
    MSG_SENT_OK="E-mail enviado com sucesso!"
    MSG_SENT_FAIL="Falha ao enviar o e-mail."
    MSG_ERR_MAIL="ATENÇÃO: Comando 'mail' não encontrado. Instale 'mailx' ou 'postfix'."
    
    LOG_START="Relatório de auditoria iniciado em $START_DATE no horário de $START_TIME"
    LOG_END_P1="Relatório finalizado em"
    LOG_END_P2="no horário de"
    LOG_END_P3="Arquivo de relatório gerado em"
    LOG_MAIL_OK="e email enviado para"
    LOG_MAIL_FAIL="mas falhou ao enviar email para"
    LOG_MAIL_ERR="e email não enviado (comando mail ausente)"
    
    MAIL_SUBJ="[Relatório Fortis] - WordPress ($START_DATE)"
    MAIL_BODY="Segue em anexo relatório de sites contendo administradores suspeitos e usuários fora do padrão."
else
    MSG_START="Starting smart audit on"
    MSG_ACCOUNTS="accounts"
    MSG_IGNORE="Ignoring admins listed in Whitelist..."
    MSG_PROC="Processing"
    MSG_DONE="Process Completed"
    MSG_SAVED="Report saved to"
    MSG_SENDING="Sending report to"
    MSG_SENT_OK="Email sent successfully!"
    MSG_SENT_FAIL="Failed to send email."
    MSG_ERR_MAIL="WARNING: 'mail' command not found."
    
    LOG_START="Audit report started on $START_DATE at $START_TIME"
    LOG_END_P1="Audit report finished on"
    LOG_END_P2="at"
    LOG_END_P3="Report file generated at"
    LOG_MAIL_OK="and email sent to"
    LOG_MAIL_FAIL="but failed to send email to"
    LOG_MAIL_ERR="and email not sent"
    
    MAIL_SUBJ="[Relatório Fortis] - WordPress ($START_DATE)"
    MAIL_BODY="Attached is the report of sites containing suspicious administrators and non-standard users."
fi

# Fixed columns
CSV_HEAD="DOMAIN,COUNTER,ADMIN_LIST,OTHER_USERS"

echo "$LOG_START" >> "$LOG_FILE"
echo "$CSV_HEAD" > "$CSV_FILE"

# List directories and apply Debug Limit
DIRS=(/home/*)
if [ "$DEBUG_MODE" = true ]; then
    echo "--- MODO DEBUG ATIVADO (Limitando a 5 domínios) ---"
    DIRS=("${DIRS[@]:0:5}")
fi

TOTAL=${#DIRS[@]}
CURRENT=0

echo "$MSG_START $TOTAL $MSG_ACCOUNTS..."
echo "----------------------------------------------------------------"

for user_dir in "${DIRS[@]}"; do
    ((CURRENT++))
    user=$(basename "$user_dir")
    wp_path="${user_dir}/public_html" 
    
    PERCENT=$(( (CURRENT * 100) / TOTAL ))
    printf "\r[%-3d%%] %s: %-25s" "$PERCENT" "$MSG_PROC" "$user"

    if [ -d "$wp_path" ] && [ -f "$wp_path/wp-config.php" ]; then
        
        # Get domain from DirectAdmin
        domain=""
        if [ -f "/usr/local/directadmin/data/users/$user/user.conf" ]; then
            domain=$(grep "domain=" /usr/local/directadmin/data/users/"$user"/user.conf 2>/dev/null | cut -d= -f2 | head -n1)
        fi
        [ -z "$domain" ] && domain=$user

        # Get ALL users
        RAW_DATA=$(sudo -u "$user" -- "$WP_BIN" user list --fields=user_login,user_email,roles --format=csv --skip-plugins --skip-themes --path="$wp_path" 2>/dev/null)

        COUNTER=0
        ADMIN_LIST=""
        OTHER_USERS=""

        if [ -n "$RAW_DATA" ]; then
            # Skip the wp-cli header
            while IFS=, read -r login email roles; do
                login=$(echo "$login" | tr -d '\r')
                email=$(echo "$email" | tr -d '\r')
                roles=$(echo "$roles" | tr -d '\r')
                
                # Check if the current email address is on the whitelist.
                is_whitelisted=false
                if [[ " $WHITELIST_EMAILS " =~ " $email " ]]; then
                    is_whitelisted=true
                fi

                # 1. Suspicious Admins (Role is Admin AND NOT in Whitelist)
                if [[ "$roles" == *"administrator"* ]]; then
                    if [ "$is_whitelisted" = false ]; then
                        ((COUNTER++))
                        [ -z "$ADMIN_LIST" ] && ADMIN_LIST="$login ($email)" || ADMIN_LIST="$ADMIN_LIST; $login ($email)"
                    fi
                fi

                # 2. Check for "Others" (Not Whitelist, Not Gmail/Hotmail, Not Domain)
                if [ "$is_whitelisted" = false ]; then
                    email_domain=$(echo "$email" | cut -d'@' -f2)
                    
                    # It ignores common providers and emails that end with the website's own domain.
                    if [[ "$email_domain" != "gmail.com" && \
                          "$email_domain" != "hotmail.com" && \
                          "$email_domain" != "outlook.com" && \
                          "$email_domain" != "$domain" && \
                          "$email" != *"@$domain" ]]; then
                        
                        [ -z "$OTHER_USERS" ] && OTHER_USERS="$login ($email)" || OTHER_USERS="$OTHER_USERS; $login ($email)"
                    fi
                fi

            done <<< "$(echo "$RAW_DATA" | tail -n +2)"
        fi

        # Write to CSV if suspicious admins OR other users found
        if [ "$COUNTER" -gt 0 ] || [ -n "$OTHER_USERS" ]; then
            echo "$domain,$COUNTER,\"$ADMIN_LIST\",\"$OTHER_USERS\"" >> "$CSV_FILE"
        fi
    fi
done

echo -e "\n\n--- $MSG_DONE ---"
echo "$MSG_SAVED: $CSV_FILE"

# Capture End Time
END_DATE=$(date +"%d-%m-%y")
END_TIME=$(date +"%H:%M:%S")

# Email Routine
if command -v mail &> /dev/null; then
    # Displays the emails in the log (converts array to string for echo).
    echo "$MSG_SENDING ${RECIPIENT_MAIL[*]}..."
    
    FINAL_BODY="$MAIL_BODY"
    
    # IMPORTANT: "${RECIPIENT_MAIL[@]}" expands each item in the array as a separate argument.
    echo "$FINAL_BODY" | mail -s "$MAIL_SUBJ" -a "$CSV_FILE" "${RECIPIENT_MAIL[@]}"
    
    if [ $? -eq 0 ]; then
        echo "$MSG_SENT_OK"
        LOG_MAIL_STATUS="$LOG_MAIL_OK ${RECIPIENT_MAIL[*]}"
    else
        echo "$MSG_SENT_FAIL"
        LOG_MAIL_STATUS="$LOG_MAIL_FAIL ${RECIPIENT_MAIL[*]}"
    fi
else
    echo "$MSG_ERR_MAIL"
    LOG_MAIL_STATUS="$LOG_MAIL_ERR"
fi

LOG_END="$LOG_END_P1 $END_DATE $LOG_END_P2 $END_TIME: $LOG_END_P3 $CSV_FILE $LOG_MAIL_STATUS"
echo "$LOG_END" >> "$LOG_FILE"
echo "--------------------------------------------------------------------------------" >> "$LOG_FILE"