sed -ri 's/.*swap.*/#&/' /etc/fstab
swapoff -a && swapon -a