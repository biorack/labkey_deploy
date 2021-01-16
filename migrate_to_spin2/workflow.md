# Moving metatlas-dev.nersc.gov on SPIN1 to metatlas.nersc.gov on SPIN2

## Setup

### Clone this repo to a cori login node
```
git clone https://github.com/biorack/labkey_deploy
```

### Get a TLS certificate
Get a cert for metatlas.nersc.gov from [certificates.lbl.gov](https://certificates.lbl.gov/).
If it gives you an error about not being authorized on the domain, then email nersc-ssl-certs@lbl.gov.

In the root of this repo:
```
touch .tls.key
chmod 600 .tls.key
```
In the root of this repo save the private key as .tls.key and the certificate as .tls.cert.


### Create a .secrets file
In the root of this repo:

```
touch .secrets
chmod 600 .secrets
echo "POSTGRES_PASSWORD=MyPasswordGoesHere" > .secrets
echo "MASTER_ENCRYPTION_KEY=MyEncryptionKeyGoesHere" >> .secrets
```

See the [LabKey documentation](https://www.labkey.org/Documentation/wiki-page.view?name=cpasxml#encrypt)
for more information on the MASTER_ENCRYPTION_KEY. The MASTER_ENCRYPTION_KEY should remain the same
between SPIN1 and SPIN2.

### Clone this repo to your local machine
```
git clone https://github.com/biorack/labkey_deploy

```

### Build and push containers
```
labkey_deploy/build.sh --all --project lims --registry registry.spin.nersc.gov
BACKUP_RESTORE=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep -E "registry.*backup_restore:" | head -1)
LABKEY=$(docker images --format "table {{.Repository}}:{{.Tag}}" | grep -E "registry.*labkey:" | head -1)
echo "./deploy.sh -b $BACKUP_RESTORE -l $LABKEY"
```
Copy the deploy command that is echoed to your terminal.

## Backup and shutdown metatlas-dev.nersc.gov on SPIN1
On a cori login node, run `./shutdown-metatlas-dev.sh`

## Deploy on Rancher2
Using the [rancher2 web UI](https://rancher2.spin.nersc.gov/), go into the production:m2650 project. Create persistant volumes called db-data and labkey-files. Each should use NFS and be 10GB.

On a cori login node, cd into the labkey_deploy repo and then run the deploy command on your clipboard.

## Test application

Login to web interface at [metatlas.nersc.gov](https://metatlas.nersc.gov) and make sure everything looks okay.

