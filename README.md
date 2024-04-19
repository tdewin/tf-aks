# Warning!
All Kubernetes API and ingresses will publically accessible by default


# az login
make sure az works eg 
```bash
az vm list
```

# az only supports rsa
Make sure id_rsa.pub contains ssh-rsa key
```bash
ssh-keygen -t rsa
```
https://github.com/Azure/AKS/issues/3434
https://learn.microsoft.com/en-us/troubleshoot/azure/virtual-machines/linux/ed25519-ssh-keys
https://learn.microsoft.com/en-us/azure/virtual-machines/linux/ssh-from-windows


# apply 
```
tf -chdir=aks_stage1 init
tf -chdir=aks_stage1 apply -var='ownerref=jdoe' -var='owneremail=jdoe@acmecompany.com' -var='project=tfdemo'

tf -chdir=aks_stage2 init
tf -chdir=aks_stage2 apply
```

