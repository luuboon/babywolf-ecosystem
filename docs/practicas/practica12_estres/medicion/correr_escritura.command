#!/usr/bin/env bash
cd "$HOME/Flutter/babywolf-ecosystem" && git pull --ff-only -q 2>/dev/null
bash "$HOME/Flutter/babywolf-ecosystem/docs/practicas/practica12_estres/medicion/correr_escritura.sh"
echo; echo "Terminó. Puedes cerrar esta ventana."; sleep 2
