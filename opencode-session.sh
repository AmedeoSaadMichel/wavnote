#!/bin/zsh

echo "🚀 Avvio sessione di lavoro OpenCode..."
# Avvia opencode passando eventuali argomenti aggiuntivi
opencode "$@"

# Questo blocco viene eseguito SOLO quando chiudi l'interfaccia di OpenCode
echo "\n========================================================"
echo "📝 Chiusura rilevata. Esecuzione 'Stop Hook' automatico..."
echo "Aggiornamento della Vault Obsidian in corso (features, tech-debt, log)..."
echo "========================================================\n"

# Esegue il comando custom /wrapup continuando l'ultima sessione (-c)
opencode run "/wrapup" -c

echo "\n✅ Procedura di Wrap-up completata. Vault aggiornata. Alla prossima!"
