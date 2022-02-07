Java keystore manager
Author: Sergii Kulyk aka Saboteur

Certificate console panel manager for Linux shell

Video demo is better that just reading the text, so kindly check demo: https://asciinema.org/a/SORBcJ1hndJ9QluGa5FVnoPHl

Requirements:
	sed, grep and keytool from jdk should be available in PATH
	It should work fine under bash, ksh, zsh and possibly all posix modern shells

Features:
	Browse keystores supported by keytool (JKS, PKCS12)
	Available actions with certificates and keystores:
		View details, Rename, Delete, Export to JKS, PKCS12, CER, PEM formats,
		Import (directly from web-site)
	in two-panel mode also available: Copy, Compare (by cert serial ID)

Usage:
	jks_mgr.sh <keystore>
		open jks mgr in single-panel mode
	jks_mgr.sh <keystore1> <keystore2>
		open jks mgr in two-panel mode
	jks_mgr.sh --update
		Automatically check and download new version from github
		https://raw.githubusercontent.com/sfkulyk/jks-manager/master/jks_mgr.sh
	jks_mgr.sh --version
		Show current version
	jks_mgr.sh --help
		Show this help
