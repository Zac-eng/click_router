all:
	sudo click --dpdk -c 0xf -n 4 -- main.click

hugepage:
	# sudo su
	echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
	# exit
