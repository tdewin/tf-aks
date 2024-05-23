# Warning!
All Kubernetes API and ingresses will publically accessible by default. You can limit the ip range with the variable "allowips" which is by default 0.0.0.0/0 or basically the whole internet. Make sure to use a /32 if you want to allow only a single ip.


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

# access
Your ingress will have a self signed certificate by default with owner (above jdoe) and project name (tfdemo):
https://jdoe.tfdemo.test/k10/?page=Login#/login
https://jdoe.tfdemo.test/stock/init

You have to add the dns to your dns server or to make an entry in etc host. The data is store in the output etchostingress


**THIS IS SENSITIVE INFO**

the kubeconfig is in the output as well, you can access it with. A token will be generated for 36h by default as well to login into kasten. You can change the variable for this if you want a longer token (because your demo takes longer). There is also a persistent token "vbrtoken" for VBR integration
```
tofu output -raw kube_config
tofu output -raw k10token
```