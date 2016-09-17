plan: tmp/amoeba-ssh
	terraform plan

run: tmp/amoeba-ssh
	terraform apply

tmp:
	mkdir -p tmp

tmp/amoeba-ssh: tmp
	ssh-keygen -q -f tmp/amoeba-ssh -N '' -C 'amoeba'
