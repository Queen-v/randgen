perl ./runall-new.pl --basedir=$1 --threads=8 --duration=250 --engine=Aria --seed=1 --scenario=CrashUpgrade --grammar=mdev20737.yy --skip-gendata --gendata-advanced --mysqld=--aria-encrypt-tables=1 --mysqld=--file-key-management --mysqld=--file-key-management-filename=`pwd`/data/file_key_management_keys.txt --mysqld=--plugin-load-add=file_key_management --vardir=/dev/shm/vardir_mdev20737