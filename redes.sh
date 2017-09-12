#!bin/bash

#===============================================================================================
#INFO
#===============================================================================================
#AUTORES: Alfonso Sebares, Oscar Ruiz
#PAREJA:  11
#GRUPO:   1361
#
#===============================================================================================
#FUENTES, DOCUMENTACION
#===============================================================================================
#Sobre divisiones de resultados de otros comandos:
#	(1)	http://unix.stackexchange.com/questions/24035/how-to-calculate-values-in-a-shell-script
#	(2)	http://stackoverflow.com/questions/12147040/division-in-script-and-floating-point
#
#Colores *-*
#	(1) https://linuxtidbits.wordpress.com/2008/08/11/output-color-on-bash-scripts/
#
#Sobre display filters (y capture filters):
#	https://wiki.wireshark.org/DisplayFilters
#
#
#Notacion de display filters:
#Comparison operators					|	Logical expressions		
#eq, ==    Equal						|	and, &&   Logical AND
#ne, !=    Not Equal					|	or,  ||   Logical OR
#gt, >     Greater than					|	not, !    Logical NOT
#lt, <     Less Than					|	
#ge, >=    Greater than or Equal to		|	
#le, <=    Less than or Equal to		|	
#
#Series con X granularidad:
#	traza.pcap -qz io,stat,1,"eth" NO VA, EQUIVALENTE A traza.pcap -qz io,stat,1,"not(not eth)"
#
#Sobre 'awk script embedding in a bash script':
#	(1) http://www.linuxtopia.org/online_books/advanced_bash_scripting_guide/wrapper.html
#
#	(2) Pillar la N columna de un fichero:
#			http://stackoverflow.com/questions/11668621/how-to-get-the-first-column-of-every-line-from-a-csv-file
#	(3) http://stackoverflow.com/questions/28087461/awk-print-is-not-working-inside-bash-shell-script
#	(4) Entrelazando shell + awk:
#			https://www.cyberciti.biz/faq/bash-scripting-using-awk/
#
#Sobre 'python embedding in bash scripts':
#	(1) http://bhfsteve.blogspot.com.es/2014/07/embedding-python-in-bash-scripts.html
#
#Sobre bash para princpiantes:
#	(1) http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_07_02.html
#
#==============================================================================================
#FUNCIONES AUX
#==============================================================================================

#BRIEF: Limpia y pinta la cabecera de ejecucion
pintar_cabecera(){
	clear
	printf "====================${blu}Script de analisis${reset}===================="
	printf "\nAlfonso Sebares, Oscar Ruiz (2016)"
	printf "\nPareja 11, Grupo 1361\n"
}

#BRIEF: Descriptor de funciones del script
pintar_info_uso(){
	echo "\nUso:"
	echo "\tsh $0 [OPCION]\n"
	echo "Descripcion:"
	echo "\t${bold}--all${reset}"
	echo "\t\tEjecuta el script completo, apartados 1-6 de Funcionalidad.\n"
	echo "\t${bold}--ranking${reset}"
	echo "\t\tSe mostraran los porcentajes de paquetes IP/NO-IP y el top10, apartados 1-2.\n"
	echo "\t${bold}--stats${reset}"
	echo "\t\tSe generaran los archivos propios a las ECDFs y sus plots, apartados 3-6.\n"
	echo "\t${bold}--clean${reset}"
	echo "\t\tSe eliminan todos los ficheros .out .txt Graficas/.jpeg de ejecuciones anteriores\n"
}

#BRIEF: Comprueba si existe la traza
check_traza(){
	if [ ! -f traza.pcap ]; then
	    echo "\nERROR: no se ha encontrado la traza .pcap"
	    exit 1
	fi
}

#REQUIERE: ips_framelen.out
#BRIEF:    Genera una lista con awk de 2 columnas: <suma frame.len>" "<ip asociada>
awk_ips(){
	awk '
	BEGIN {
		FS = "\t";
	}
	{
		suma_valores[$1] = suma_valores[$1] + $2;
	}
	END{
		for(valor in suma_valores){
			print suma_valores[valor]" \t"valor;
		}
	}
	' "ips_framelen.out" | sort -rn | head -n 10
}

#REQUIERE: tcp_port_framelen.out, udp_port_famelen.out
#BRIEF:    Genera una lista con awk de 2 columnas: <suma frame.len>" "<puerto asociado>

awk_ports(){
awk '
	BEGIN {
		FS = "\t";
	}
	{
		suma_valores[$1] = suma_valores[$1] + $2;
	}
	END{
		for(valor in suma_valores){
			print suma_valores[valor]"\t"valor;
		}
	}
	' "$1" | sort -rn | head -n 10
}

#REQUIERE: throughput.out
#BRIEF:    Procesa la salida del comando de estadisticas avanzadas de tshark.
#		   (tabla con el 'throughput').
#GENERA:   throughput.txt
procesaTabla() {
python - << EOF
import sys
import csv

f = open('throughput.out','r')
#saltarse la cabecera de la tabla y ultima linea
line_list = f.readlines()[11:-1]
#quitar ruido
line_list[:] = [x.replace('\n', '').replace('\r', '').replace(' ','') for x in line_list]

table = []
for line in line_list:
    table.append(line.split('|'))

for row in table:
    del row[0]
    del row[1]
    del row[1]
    del row[3]
    del row[3]
for row in table:
    #que hacer con row[0]
    row[1] = int(row[1])
    row[2] = int(row[2])

with open('throughput.txt', 'w') as csvfile:
    writer = csv.writer(csvfile, delimiter=' ')
    [writer.writerow(r) for r in table]
EOF
}

#REQUIERE: throughput.out
#BRIEF:    Genera la grafica del throughput, carpeta Graficas
#GENERA:   Graficas/throughput.jpeg
plot_throughput(){
gnuplot -persist <<-EOFMarker
	set term jpeg
	set output "Graficas/thoughput_$1.jpeg"
	set title "Throughput $1" font ",14" textcolor rgbcolor "royalblue"
	set xlabel "intervalo (s)"
	set ylabel "bytes"
	plot "throughput.txt" using 1:3 with lines title "Datos"
EOFMarker
}

toplot(){
gnuplot -persist <<-EOFMarker
	set term dumb	
	set title "$2" font ",14" textcolor rgbcolor "royalblue"
	set xlabel "$3"
	set ylabel "$4"
	set term jpeg
	set output "Graficas/$1.jpeg"
	plot "salida.txt" using 1:2 with steps title "$5"
	replot
	exit
EOFMarker
}

toplottime(){
gnuplot -persist <<-EOFMarker
	set term dumb	
	set title "$2" font ",14" textcolor rgbcolor "royalblue"
	set xlabel "$3"
	set ylabel "$4"
	set logscale x
	set term jpeg
	set output "Graficas/$1.jpeg"
	plot "salida.txt" using 1:2 with steps title "$5"
	
	replot
	exit
EOFMarker
}
#==============================================================================================
#FUNCIONES TRONCALES
#==============================================================================================

#REQUIERE: los siguientes nombres de ficheros libres (se abren si existen/generan en la funcion):
#			=> ips_framelen.out		
#			=> tcp_port_framelen.out
#			=> udp_port_framelen.out
#			
#BRIEF:    realiza todas las oepraciones de los apartados 1-2
ranking(){
	#Ficheros para luego filtrar
	echo "\n${green}NO CORTAR LA EJECUCION${red}"
	echo "${green}Generando ficheros auxiliares...${reset}"
	printf "[${green}                         ${reset}](0%%)\r"
	#
	#if [ ! -f ips.out ]; then
	#	tshark -r traza.pcap -T fields -e ip.src > ips.out
	#	tshark -r traza.pcap -T fields -e ip.dst >> ips.out
	#fi

	#Para top ips (apariciones)+ top ips (bytes)
	#fichero (ip.src primero y despues ip.dst concatenado): ip | frame.len
	if [ ! -f ips_framelen.out ]; then
		tshark -r traza.pcap -T fields -e ip.src -e frame.len -Y 'ip' > ips_framelen.out
		tshark -r traza.pcap -T fields -e ip.dst -e frame.len -Y 'ip' >> ips_framelen.out
	fi
	printf " [${green}########                 ${reset}](33%%)\r"

	if [ ! -f tcp_port_framelen.out ]; then
		tshark -r traza.pcap -T fields -e tcp.srcport -e frame.len -Y 'ip.proto==6' > tcp_port_framelen.out
		tshark -r traza.pcap -T fields -e tcp.dstport -e frame.len -Y 'ip.proto==6' >> tcp_port_framelen.out
	fi
	printf " [${green}################         ${reset}](66%%)\r"

	if [ ! -f udp_port_framelen.out ]; then
		tshark -r traza.pcap -T fields -e udp.srcport -e frame.len -Y 'ip.proto==17' > udp_port_framelen.out
		tshark -r traza.pcap -T fields -e udp.dstport -e frame.len -Y 'ip.proto==17' >> udp_port_framelen.out
	fi

	printf " [${green}#########################${reset}](100%%)\r"
	printf "\n"

	#Counts
	echo "${green}Filtrando paquetes...${reset}"
	printf " [${green}                         ${reset}](0%%)\r"
	count_todos=$(tshark -r traza.pcap -Y 'eth' | wc -l)
	count_eth_ip=$(tshark -r traza.pcap -Y '(eth.type==0x8100 && vlan.etype==0x0800) || eth.type==0x0800' | wc -l)
	printf " [${green}#####                    ${reset}](20%%)\r"
	count_eth_NO_ip=$(tshark -r traza.pcap -Y '!((eth.type==0x8100 && vlan.etype==0x0800) || eth.type==0x0800)' | wc -l)
	printf " [${green}##########               ${reset}](40%%)\r"
	count_tcp=$(tshark -r traza.pcap -Y '((eth.type==0x8100 && vlan.etype==0x0800) || eth.type==0x0800) && tcp' | wc -l)
	printf " [${green}###############          ${reset}](60%%)\r"
	count_udp=$(tshark -r traza.pcap -Y '((eth.type==0x8100 && vlan.etype==0x0800) || eth.type==0x0800) && udp' | wc -l)
	printf " [${green}####################     ${reset}](80%%)\r"
	count_others=$(tshark -r traza.pcap -Y '((eth.type==0x8100 && vlan.etype==0x0800) || eth.type==0x0800) && !(tcp || udp)' | wc -l)
	printf " [${green}#########################${reset}](100%%)\r"

	echo "\n\nEn total:\t\t $count_todos"
	echo "IP:\t\t\t $count_eth_ip"
	echo "NO IP:\t\t\t $count_eth_NO_ip"
	echo "TCP:\t\t\t $count_tcp"
	echo "UDP:\t\t\t $count_udp"
	echo "Other:\t\t\t $count_others"

	#3 formas de hacerlo:
	#div=$(echo "scale=6; 100*$count_eth_ip/$count_todos" | bc )
	#div=$(echo "scale=6; 100*$count_eth_ip/$count_todos" | bc | awk '{printf "%f", $0}')
	div=$(echo "scale=6; x=100*$count_eth_ip/$count_todos; if(x<1) print 0; x" | bc )
	echo "\nPorcentaje paquetes ${blu}ETH|IP${reset} ó ${blu}ETH|VLAN|IP${reset}:\t\t$div%"

	#3 formas de hacerlo:
	#div=$(echo "scale=6; 100*$count_eth_NO_ip/$count_todos" | bc)
	#div=$(echo "scale=6; 100*$count_eth_NO_ip/$count_todos" | bc | awk '{printf "%f", $0}')
	div=$(echo "scale=6; x=100*$count_eth_NO_ip/$count_todos; if(x<1) print 0; x" | bc )
	echo "Porcentaje paquetes ${blu}NOT (ETH|IP ó ETH|VLAN|IP)${reset}:\t\t$div%"

	div=$(echo "scale=6; x=100*$count_tcp/$count_eth_ip; if(x<1) print 0; x" | bc )
	echo "Porcentaje paquetes ${blu}TCP${reset} sobre IP:\t\t\t$div%"

	div=$(echo "scale=6; x=100*$count_udp/$count_eth_ip; if(x<1) print 0; x" | bc )
	echo "Porcentaje paquetes ${blu}UDP${reset} sobre IP:\t\t\t$div%"

	div=$(echo "scale=6; x=100*$count_others/$count_eth_ip; if(x<1) print 0; x" | bc )
	echo "Porcentaje paquetes ${blu}otro${reset} tipo sobre IP:\t\t\t$div%"

	echo "\nTops:"

	echo "Direcciones IP más activas en ${blu}número de paquetes${reset}:"
	top_ips_paquetes=$(awk -F"\t" '{print $1}' ips_framelen.out | sort | uniq -c | sort -rn | head -n 10)
	echo "$top_ips_paquetes"

	echo "\nDirecciones IP más activas en ${blu}número de bytes${reset}: "
	#tshark -r traza.pcap -T fields -e ip.src -e ip.dst -e frame.len -Y 'ip' > todos.out
	#filtered_count=$(wc -l < ips_framelen.out)

	awk_ips

#	echo "\nPuertos más activos en ${blu}número de paquetes${reset}: "
#	top_puertos_paquetes=$(awk -F"\t" '{print $1}' port_framelen.out | sort | uniq -c | sort -rn | head -n 10)
#	echo "$top_puertos_paquetes"

#	echo "\nPuertos más activos en ${blu}número de bytes${reset}: "
#	awk_ports

	echo "\nPuertos ${blu}TCP${reset} más activos en ${blu}número de paquetes${reset}: "
	top_puertos_paquetes=$(awk -F"\t" '{print $1}' tcp_port_framelen.out | sort | uniq -c | sort -rn | head -n 10)
	echo "$top_puertos_paquetes"

	echo "\nPuertos ${blu}TCP${reset} más activos en ${blu}número de bytes${reset}: "
	awk_ports tcp_port_framelen.out

	echo "\nPuertos ${blu}UDP${reset} más activos en ${blu}número de paquetes${reset}: "
	top_puertos_paquetes=$(awk -F"\t" '{print $1}' udp_port_framelen.out | sort | uniq -c | sort -rn | head -n 10)
	echo "$top_puertos_paquetes"

	echo "\nPuertos ${blu}UDP${reset} más activos en ${blu}número de bytes${reset}: "
	awk_ports udp_port_framelen.out
}

#REQUIERE: los siguientes nombres de ficheros libres (se abren si existen/generan en la funcion):
#			=> throughput.out		
#			=> eth_src.txt
#			=> tcp_dst.txt
#			=> tcp_src.txt
#			=> udp_dst.txt
#			=> udp_src.txt
#			=> tcp_dst_time.txt
#			=> tcp_src_time.txt
#			=> udp_dst_time.txt
#			=> udp_src_time.txt
#			
#BRIEF:    realiza todas las oepraciones de los apartados 3-6
#GENERA: genera los ficheros .txt anteriores y las plots de cada apartado en Graficas.
stats(){
	#query para el throughput
	#	eth="..." AND ((tcp AND "ip") OR (udp AND "puerto"))
	tshark -r traza.pcap -qz io,stat,1,"(eth.src==00:11:88:CC:33:1B)&&((tcp && ip.addr==37.246.132.71)||(udp && udp.port==54189))" > throughput.out
	procesaTabla
	plot_throughput origen

	tshark -r traza.pcap -qz io,stat,1,"(eth.dst==00:11:88:CC:33:1B)&&((tcp && ip.addr==37.246.132.71)||(udp && udp.port==54189))" > throughput.out
	procesaTabla
	plot_throughput destino

	echo "\n${green}Generando Estadisticas...${reset}"
	printf " [${green}                         ${reset}](0%%)\r"

	tshark -r traza.pcap -T fields -e frame.len -Y eth.src==00:11:88:CC:33:1B | sort -n -r | uniq -c | sort -n -k 2 > eth_src.txt
	printf " [${green}##                       ${reset}](10%%)\r"

	tshark -r traza.pcap -T fields -e frame.len -Y eth.dst==00:11:88:CC:33:1B | sort -n -r | uniq -c | sort -n -k 2 > eth_dst.txt
	printf " [${green}#####                    ${reset}](20%%)\r"

	tshark -r traza.pcap -T fields -e frame.len -Y '(eth.addr==00:11:88:CC:33:1B && tcp.dstport==80)' | sort -n -r | uniq -c | sort -n -k 2 > tcp_dst.txt
	printf " [${green}######                   ${reset}](30%%)\r"

	tshark -r traza.pcap -T fields -e frame.len -Y '(eth.addr==00:11:88:CC:33:1B && tcp.srcport==80)' | sort -n -r | uniq -c | sort -n -k 2 > tcp_src.txt
	printf " [${green}#########               ${reset}](40%%)\r"

	tshark -r traza.pcap -T fields -e frame.len -Y '(eth.addr==00:11:88:CC:33:1B && udp.dstport==53)' | sort -n -r | uniq -c | sort -n -k 2 > udp_dst.txt
	printf " [${green}############            ${reset}](50%%)\r"

	tshark -r traza.pcap -T fields -e frame.len -Y '(eth.addr==00:11:88:CC:33:1B && udp.srcport==53)' | sort -n -r | uniq -c | sort -n -k 2 > udp_src.txt
	printf " [${green}###############         ${reset}](60%%)\r"

	tshark -r traza.pcap -T fields -e frame.time_delta_displayed -Y '(eth.addr==00:11:88:CC:33:1B && ip.dst==37.246.132.71 && ip.proto==6)' | sort -n -r | uniq -c | sort -n -k 2 > tcp_dst_time.txt
	printf " [${green}#################       ${reset}](70%%)\r"

	tshark -r traza.pcap -T fields -e frame.time_delta_displayed -Y '(eth.addr==00:11:88:CC:33:1B && ip.src==37.246.132.71 && ip.proto==6)' | sort -n -r | uniq -c | sort -n -k 2 > tcp_src_time.txt
	printf " [${green}####################    ${reset}](80%%)\r"

	tshark -r traza.pcap -T fields -e frame.time_delta_displayed -Y '(eth.addr==00:11:88:CC:33:1B && ip.proto==17 && udp.dstport==54189)' | sort -n -r | uniq -c | sort -n -k 2 > udp_dst_time.txt
	printf " [${green}######################  ${reset}](90%%)\r"

	tshark -r traza.pcap -T fields -e frame.time_delta_displayed  -Y '(eth.addr==00:11:88:CC:33:1B && ip.proto==17 && udp.srcport==54189)' | sort -n -r | uniq -c | sort -n -k 2 > udp_src_time.txt
	printf " [${green}########################${reset}](100%%)\r"

	echo "\n${green}Compilando crearCDF.c...${reset}"
	gcc -Wall -o crearCDF crearCDF.c

	echo "${green}Generando ECDFs...${reset}"

	#eth_src.txt
	if [ -s eth_src.txt ]; then
		#./crearCDF eth_src.txt | sh toplot.sh eth_src.txt "ECDF de los tamaños a nivel 2 de los paquetes eth fuente" "Tamano Paquetes" "Porcentaje Paquetes" "Datos"
		./crearCDF eth_src.txt
		toplot eth_src.txt "ECDF de los tamaños a nivel 2 de los paquetes eth fuente" "Tamano Paquetes" "Porcentaje Paquetes" "Datos"
	else
		echo "${orange}[WARNING]: eth_src.txt vacio, no se genera plot${reset}"
	fi

	#eth_dst.txt
	if [ -s eth_dst.txt ]; then
		#./crearCDF eth_dst.txt | sh toplot.sh eth_dst.txt "ECDF de los tamaños a nivel 2 de los paquetes eth destino" "Tamano Paquetes" "Porcentaje Paquetes" "Datos"
		./crearCDF eth_dst.txt
		toplot eth_dst.txt "ECDF de los tamaños a nivel 2 de los paquetes eth destino" "Tamano Paquetes" "Porcentaje Paquetes" "Datos"
	else
		echo "${orange}[WARNING]: eth_dst.txt vacio, no se genera plot${reset}"
	fi

	#tcp_src.txt
	if [ -s tcp_src.txt ]; then
		#./crearCDF tcp_src.txt | sh toplot.sh tcp_src.txt "ECDF de los tamaños a nivel 2 de los paquetes TCP fuente" "Tamano Paquetes" "Porcentaje Paquetes" "Datos"
		./crearCDF tcp_src.txt
		toplot tcp_src.txt "ECDF de los tamaños a nivel 2 de los paquetes TCP fuente" "Tamano Paquetes" "Porcentaje Paquetes" "Datos"
	else
		echo "${orange}[WARNING]: tcp_src.txt vacio, no se genera plot${reset}"
	fi

	#tcp_dst.txt
	if [ -s tcp_dst.txt ]; then
		#./crearCDF tcp_dst.txt | sh toplot.sh tcp_dst.txt "ECDF de los tamaños a nivel 2 de los paquetes TCP destino" "Tamano Paquetes" "Porcentaje Paquetes" "Datos"
		./crearCDF tcp_dst.txt
		toplot tcp_dst.txt "ECDF de los tamaños a nivel 2 de los paquetes TCP destino" "Tamano Paquetes" "Porcentaje Paquetes" "Datos"
	else
		echo "${orange}[WARNING]: tcp_dst.txt vacio, no se genera plot${reset}"
	fi

	#udp_src.txt
	if [ -s udp_src.txt ]; then
		#./crearCDF udp_src.txt | sh toplot.sh udp_src.txt "ECDF de los tamaños a nivel 2 de los paquetes UDP fuente" "Tamano Paquetes" "Porcentaje Paquetes" "Datos"
		./crearCDF udp_src.txt
		toplot udp_src.txt "ECDF de los tamaños a nivel 2 de los paquetes UDP fuente" "Tamano Paquetes" "Porcentaje Paquetes" "Datos"
	else
		echo "${orange}[WARNING]: udp_src.txt vacio, no se genera plot${reset}"
	fi

	#udp_dst.txt
	if [ -s udp_dst.txt ]; then
		#./crearCDF udp_dst.txt | sh toplot.sh udp_dst.txt "ECDF de los tamaños a nivel 2 de los paquetes UDP destino" "Tamano Paquetes" "Porcentaje Paquetes" "Datos"
		./crearCDF udp_dst.txt
		toplot udp_dst.txt "ECDF de los tamaños a nivel 2 de los paquetes UDP destino" "Tamano Paquetes" "Porcentaje Paquetes" "Datos"
	else
		echo "${orange}[WARNING]: udp_dst.txt vacio, no se genera plot${reset}"
	fi

	#tcp_dst_time.txt
	if [ -s tcp_dst_time.txt ]; then
		#./crearCDF tcp_dst_time.txt | sh toplottime.sh tcp_dst_time.txt "ECDF de los tiempos entre llegadas del flujo TCP destino" "Tiempos" "Porcentaje Tiempo" "Datos"
		./crearCDF tcp_dst_time.txt
		toplottime tcp_dst_time.txt "ECDF de los tiempos entre llegadas del flujo TCP destino" "Tiempos" "Porcentaje Paquetes" "Datos"
	else
		echo "${orange}[WARNING]: tcp_dst_time.txt vacio, no se genera plot${reset}"
	fi

	#tcp_src_time.txt
	if [ -s tcp_src_time.txt ]; then
		#./crearCDF tcp_src_time.txt | sh toplottime.sh tcp_src_time.txt "ECDF de los tiempos entre llegadas del flujo TCP fuente" "Tiempos" "Porcentaje Tiempo" "Datos"
		./crearCDF tcp_src_time.txt
		toplottime tcp_src_time.txt "ECDF de los tiempos entre llegadas del flujo TCP fuente" "Tiempos" "Porcentaje Paquetes" "Datos"
	else
		echo "${orange}[WARNING]: tcp_src_time.txt vacio, no se genera plot${reset}"
	fi

	#udp_dst_time.txt
	if [ -s udp_dst_time.txt ]; then
		#./crearCDF udp_dst_time.txt | sh toplottime.sh udp_dst_time.txt "ECDF de los tiempos entre llegadas del flujo UDP destino" "Tiempos" "Porcentaje Tiempo" "Datos"
		./crearCDF udp_dst_time.txt
		toplottime udp_dst_time.txt "ECDF de los tiempos entre llegadas del flujo UDP destino" "Tiempos" "Porcentaje Paquetes" "Datos"
	else
		echo "${orange}[WARNING]: udp_dst_time.txt vacio, no se genera plot${reset}"
	fi

	#udp_src_time.txt
	if [ -s udp_src_time.txt ]; then
		#./crearCDF udp_src_time.txt | sh toplottime.sh udp_src_time.txt "ECDF de los tiempos entre llegadas del flujo UDP fuente" "Tiempos" "Porcentaje Tiempo" "Datos"
		./crearCDF udp_src_time.txt
		toplottime udp_src_time.txt "ECDF de los tiempos entre llegadas del flujo UDP fuente" "Tiempos" "Porcentaje Paquetes" "Datos"
	else
		echo "${orange}[WARNING]: udp_src_time.txt vacio, no se genera plot${reset}"
	fi
}

#==============================================================================================
#EJECUCION, "MAIN"
#==============================================================================================

#defines
red=`tput setaf 1`
orange=`tput setaf 3`
green=`tput setaf 2`
blu=`tput setaf 4`
bold=`tput bold`
reset=`tput sgr0`

if [ ! -f traza.pcap ]; then
    echo "\n${red}ERROR: no se ha encontrado el archivo traza.pcap"
    echo "La traza debe llamarse esa forma si ya se ha generado.${reset}"
    exit 1
fi

if [ ! $# = 1 ]; then
	clear
	echo "${red}Numero de argumentos no valido.${reset}"
	pintar_info_uso
	exit 1
fi

if [ $1 = "--all" ]
then
	pintar_cabecera
	ranking
	stats
	exit 0
elif [ $1 = "--ranking" ]
then
	pintar_cabecera
	ranking
	exit 0
elif [ $1 = "--stats" ]
then
	mkdir -p Graficas
	pintar_cabecera
	stats
	exit 0
elif [ $1 = "--clean" ]
then
	rm -f Graficas/*.jpeg
	rm -f crearCDF
	rm -f *.out
	rm -f *.txt
	exit 0
else
	clear
	echo "${red}Argumento no valido.${reset}"
	pintar_info_uso
	exit 1
fi