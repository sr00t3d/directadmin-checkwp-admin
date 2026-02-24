#!/bin/bash
################################################################################
#                                                                              #
#   PROJECT: WordPress Admin Auditor (DirectAdmin)                             #
#   VERSION: 2.1.1 (Com Auditoria de Execução e Idiomas)                       #
#                                                                              #
#   AUTHOR:  Percio Andrade                                                    #
#   CONTACT: percio@evolya.com.br | contato@perciocastelo.com.br               #
#   WEB:     https://perciocastelo.com.br                                      #
#                                                                              #
#   INFO:                                                                      #
#   Audit WP admins, filter by whitelist, generate CSV, email report           #
#   and log execution history to /var/log/wp_audit.log.                        #
#                                                                              #
################################################################################

# --- SETTINGS ---
RECIPIENT_MAIL="email@dominio.com.br"

# Add allowed emails separated by SPACE.
WHITELIST_EMAILS="root@dominio.com.br dev@dominio.com.br" 

CSV_FILE="status_admins_wp_$(date +%Y%m%d).csv"
WP_BIN=$(which wp)
LOG_FILE="/var/log/wp_audit.log"
# --------------------------------

# Capture Start Time
START_DATE=$(date +"%d-%m-%y")
START_TIME=$(date +"%H:%M:%S")

# Detect System Language
SYSTEM_LANG="${LANG:0:2}"

if [[ "$SYSTEM_LANG" == "pt" ]]; then
    # Portuguese
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
    
    # Audit Logs (PT)
    LOG_START="Relatório de auditoria iniciado em $START_DATE no horário de $START_TIME"
    LOG_END_P1="Relatório finalizado em"
    LOG_END_P2="no horário de"
    LOG_END_P3="Arquivo de relatório gerado em"
    LOG_MAIL_OK="e email enviado para"
    LOG_MAIL_FAIL="mas falhou ao enviar email para"
    LOG_MAIL_ERR="e email não enviado (comando mail ausente)"
    
    # CSV Headers & Email Content
    CSV_HEAD="Dominio,Qtd_Admins,Lista_Usuarios"
    MAIL_SUBJ="Relatório de Auditoria WP - Admins Suspeitos - $(hostname)"
    MAIL_BODY="Segue em anexo relatório de sites contendo administradores que NÃO estão na whitelist"
else
    # English (Default)
    MSG_START="Starting smart audit on"
    MSG_ACCOUNTS="accounts"
    MSG_IGNORE="Ignoring admins listed in Whitelist..."
    MSG_PROC="Processing"
    MSG_DONE="Process Completed"
    MSG_SAVED="Report saved to"
    MSG_SENDING="Sending report to"
    MSG_SENT_OK="Email sent successfully!"
    MSG_SENT_FAIL="Failed to send email."
    MSG_ERR_MAIL="WARNING: 'mail' command not found. Please install 'mailx' or 'postfix'."
    
    # Audit Logs (EN)
    LOG_START="Audit report started on $START_DATE at $START_TIME"
    LOG_END_P1="Audit report finished on"
    LOG_END_P2="at"
    LOG_END_P3="Report file generated at"
    LOG_MAIL_OK="and email sent to"
    LOG_MAIL_FAIL="but failed to send email to"
    LOG_MAIL_ERR="and email not sent (mail command missing)"
    
    # CSV Headers & Email Content
    CSV_HEAD="Domain,Admin_Count,User_List"
    MAIL_SUBJ="WP Audit Report - Suspicious Admins - $(hostname)"
    MAIL_BODY="Attached is the report of sites containing administrators NOT in the whitelist"
fi

# Write Start Log to /var/log/wp_audit.log
echo "$LOG_START" >> "$LOG_FILE"

# Write CSV Header
echo "$CSV_HEAD" > "$CSV_FILE"

# Count total folders for progress bar
TOTAL=$(find /home -maxdepth 1 -type d | wc -l)
TOTAL=$((TOTAL - 1))
CURRENT=0

echo "$MSG_START $TOTAL $MSG_ACCOUNTS..."
echo "$MSG_IGNORE"
echo "----------------------------------------------------------------"

for user_dir in /home/*; do
    ((CURRENT++))
    user=$(basename "$user_dir")
    wp_path="${user_dir}/public_html" 
    # Adjustment for DirectAdmin standard structure if needed:
    # wp_path="${user_dir}/domains/${user}/public_html"
    
    # Visual Progress Bar
    if [ "$TOTAL" -gt 0 ]; then
        PERCENT=$(( (CURRENT * 100) / TOTAL ))
    else
        PERCENT=0
    fi
    printf "\r[%-3d%%] %s: %-25s" "$PERCENT" "$MSG_PROC" "$user"

    # Check valid WordPress
    if [ -d "$wp_path" ] && [ -f "$wp_path/wp-config.php" ]; then
        
        # Try to get main domain from DirectAdmin user.conf
        if [ -f "/usr/local/directadmin/data/users/$user/user.conf" ]; then
            domain=$(grep "domain=" /usr/local/directadmin/data/users/"$user"/user.conf 2>/dev/null | cut -d= -f2 | head -n1)
        fi
        [ -z "$domain" ] && domain=$user

        # Get raw admin list via WP-CLI
        RAW_DATA=$(sudo -u "$user" -- "$WP_BIN" user list --role=administrator --fields=user_login,user_email --format=csv --skip-plugins --skip-themes --path="$wp_path" 2>/dev/null)

        COUNTER=0
        ADMIN_LIST=""

        if [ -n "$RAW_DATA" ]; then
            # 'tail -n +2' removes WP-CLI CSV header
            while IFS=, read -r login email; do
                # Clean invisible chars
                login=$(echo "$login" | tr -d '\r')
                email=$(echo "$email" | tr -d '\r')

                # --- DYNAMIC WHITELIST LOGIC ---
                # Checks if current email is NOT in WHITELIST_EMAILS
                if [[ ! " $WHITELIST_EMAILS " =~ " $email " ]]; then
                    
                    ((COUNTER++))
                    
                    if [ -z "$ADMIN_LIST" ]; then
                        ADMIN_LIST="$login ($email)"
                    else
                        ADMIN_LIST="$ADMIN_LIST; $login ($email)"
                    fi
                fi
                # -------------------------------

            done <<< "$(echo "$RAW_DATA" | tail -n +2)"
        fi

        # Write to CSV if suspicious admins found
        if [ "$COUNTER" -gt 0 ]; then
            echo "$domain,$COUNTER,\"$ADMIN_LIST\"" >> "$CSV_FILE"
        fi
    fi
done

echo -e "\n\n--- $MSG_DONE ---"
echo "$MSG_SAVED: $CSV_FILE"

# Capture End Time
END_DATE=$(date +"%d-%m-%y")
END_TIME=$(date +"%H:%M:%S")

# Email Routine and End Log
if command -v mail &> /dev/null; then
    echo "$MSG_SENDING $RECIPIENT_MAIL..."
    
    FINAL_BODY="$MAIL_BODY ($WHITELIST_EMAILS)."
    
    # Send with attachment (-a)
    echo "$FINAL_BODY" | mail -s "$MAIL_SUBJ" -a "$CSV_FILE" "$RECIPIENT_MAIL"
    
    if [ $? -eq 0 ]; then
        echo "$MSG_SENT_OK"
        LOG_MAIL_STATUS="$LOG_MAIL_OK $RECIPIENT_MAIL"
    else
        echo "$MSG_SENT_FAIL"
        LOG_MAIL_STATUS="$LOG_MAIL_FAIL $RECIPIENT_MAIL"
    fi
else
    echo "$MSG_ERR_MAIL"
    LOG_MAIL_STATUS="$LOG_MAIL_ERR"
fi

# Write End Log to /var/log/wp_audit.log
LOG_END="$LOG_END_P1 $END_DATE $LOG_END_P2 $END_TIME: $LOG_END_P3 $CSV_FILE $LOG_MAIL_STATUS"

echo "$LOG_END" >> "$LOG_FILE"
# Separator for the log file
echo "--------------------------------------------------------------------------------" >> "$LOG_FILE"