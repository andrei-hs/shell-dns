#!/bin/bash
#
# Automação de DNS
#
# Andrei Henrique Santos
# CVS $Header$

shopt -s -o nounset

conf_default="/etc/bind/named.conf.default-zones"
dir_dns="/etc/bind"
loop=true
ip_fixo="0"

# Título
echo "Inicando Servidor DNS..."

# Validando permissão de super usuário
if [[ "EUID" -ne 0 ]]; then
	echo "Necessário estar em modo super usuário!"
	sleep 3
	exit 1
fi

# Atualizando pacotes
echo "Deseja instalar o Servidor DNS? (S / N)"
	read instalar
	if [[ "$instalar" == "S" || "$instalar" == "s" ]]; then
		apt-get update -y && apt-get upgrade -y
		sleep 3
	fi

# Verificando se o serviço dhcp já existe
if [ ! -e "$dir_dns/db.empty" ]; then
	echo "O servidor DNS não está instalado"
	echo "Instalando servidor..."
	sleep 3
	apt-get install bind9 -y
	sleep 2
else
	echo "O servidor DNS já está instalado!!!"
	echo "Deseja continuar a configuração mesmo assim? (S / N)"
	read verificar
	if [[ "$verificar" == "N" || "$verificar" == "n" ]]; then
		exit 1
	fi
	sleep 2
fi

# Configurando
echo "---------------------------------------------------"
echo "Hora de configurar o Servidor!!"
echo "É necessário que algumas informações sejam passadas"
echo "---------------------------------------------------"
echo "* - Obrigatório informar algo"
echo "Se preferir não informar coloque - 0"
echo "---------------------------------------------------"
echo "Deseja adicionar ip estático a máquina virtual? (S / N)"
read verificar
if [[ "$verificar" == "S" || "$verificar" == "s" ]]; then
	echo "O IP que este servidor DNS terá:*"
	read ip_fixo
	echo "A sua máscara de rede:*"
	read mask_fixo
	echo "o seu gateway:"
	read gateway
	echo "A interface em que o DNS funcionará:*"
	read interface

	# Configurando IP estático
	{
	if [[ "$gateway" == "0" ]]; then
		sed -i "s|iface $interface inet dhcp|iface $interface inet static \naddress $ip_fixo \nnetmask $mask_fixo|" "/etc/network/interfaces"
	else
		sed -i "s|iface $interface inet dhcp|iface $interface inet static \naddress $ip_fixo \nnetmask $mask_fixo \ngateway $gateway|" "/etc/network/interfaces"
	fi
	} >>"/etc/network/interfaces"
fi

# Criando zonas e as configurando
while [[ loop==true ]]; do
	echo "Zona que deseja colocar:*"
	read zone
	echo "Final da zona que deseja colocar:* (.local, .com, ...)"
	read end
	# Configurando zona no named.conf.default-zones
	zona_completa="$zone$end"
	zona_local="$dir_dns/db.$zone"
	{
	echo "zone @" {
	echo "      type master;"
	echo "      file =;"
	echo -e "};\n"

	sed -i 's/@/"x"/g' $conf_default
	sed -i "s|x|$zona_completa|g" $conf_default
	sed -i 's/=/"+"/g' $conf_default
	sed -i "s|+|$zona_local|g" $conf_default

	} >>"$conf_default"

	echo "Início da zona que seja colocar:* (www, ns1, ...)"
	read start
	echo "Ip do serviço associado a esse início da zona:* "
	read ip_service

	# Criando db. e configurando
	localhost="ns1.$zone"
	touch "$zona_local"
	{
	echo -e "; BIND reverse data file for empty rfc1918 zone\n;\n; DO NOT EDIT THIS FILE - it is used for multiple zones.\n; Instead, copy it, edit named.conf, and use that copy.\n;\n=TTL	86400\n@	IN	SOA	localhost. root.localhost. (\n			      1		; Serial\n			 604800		; Refresh\n			  86400		; Retry\n			2419200		; Expire\n			  86400 )	; Negative Cache TTL\n;\n@	IN	NS	localhost."
	echo "$start	IN	A	$ip_service"
	sed -i "s|=|$|" "$dir_dns/db.$zone"
	sed -i "s|localhost|$localhost|g" "$dir_dns/db.$zone"
	} >>"$dir_dns/db.$zone"

	echo "Deseja adicionar mais um início de zona? (S / N)"
	read verificar
	while [[ "$verificar" == "S" || "$verificar" == "s" ]]; do
		echo "Início da zona que seja colocar:* (www, ns1, ...)"
		read start
		echo "Ip do serviço associado a esse início da zona:* "
		read ip_service
		{
		echo "$start	IN	A	$ip_service"
		} >>"$dir_dns/db.$zone"

		echo "Deseja adicionar mais um início de zona? (S / N)"
		read verificar
	done

	echo "Deseja adicionar mais uma zona? (S / N)"
	read verificar
	if [[ "$verificar" == "N" || "$verificar" == "n" ]]; then
		break
	fi
done

# Configurando o resolv.conf
if [[ ! "$ip_fixo" == "0" ]]; then
	rm "/etc/resolv.conf"
	touch "/etc/resolv.conf"
	{
	echo "nameserver $ip_fixo"
	} >>"/etc/resolv.conf"
fi

echo "----------------------------------------------------------------------"
echo "Configuração realizada com sucesso!!!"
if [[ "$instalar" == "S" || "$instalar" == "s" ]]; then
	echo "Desligaremos a máquina para que possa colocar em rede interna..."
	echo "----------------------------------------------------------------------"
	sleep 4
	init 0
else
	echo "----------------------------------------------------------------------"
	sleep 3
fi

