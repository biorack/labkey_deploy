# metatlas LIMS
Configuration for running [metatlas.nersc.gov](https://metatlas.nersc.gov/),the LIMS for the
[metabolomics team](https://jgi.doe.gov/our-science/science-programs/metabolomics-technology/)
at [Joint Genome Institute](https://www.jgi.doe.gov/). This LIMS is based on the community 
edition of [LabKey](https://www.labkey.org/). The metatlas LIMS is deployed on
[NERSC](http://www.nersc.gov/)'s [SPIN](https://www.nersc.gov/systems/spin/)
platform for running containered services using [Kubernetes](https://kubernetes.io/) via
[Rancher](https://rancher.com/products/rancher/) v2.

## LabKey Installation Documentation

LabKey provides [overall installation instuctions](https://www.labkey.org/Documentation/wiki-page.view?name=manualInstall) and [instructions for setting up the required components](https://www.labkey.org/Documentation/wiki-page.view?name=installComponents#folder). But reading those docs is not necessary if deploying from this repo without modification.

## Overview of Repo

The layout of this repo is:

```
$ tree -L 2
.
├── LICENSE
├── README.md
├── backup_restore
│   ├── Dockerfile
│   ├── backup.yaml
│   ├── bin
│   ├── build.sh
│   ├── restore-root.yaml
│   └── restore.yaml
├── build.sh
├── db
│   ├── db-data.yaml
│   └── db.yaml
├── deploy.sh
├── get-cert
│   ├── get-cert.sh
│   └── get-cert.yaml
├── labkey
│   ├── Dockerfile
│   ├── bin
│   ├── build.sh
│   ├── config
│   ├── labkey-files.yaml
│   ├── labkey.yaml
│   └── lb.yaml
└── migrate_to_spin2
    ├── shutdown-metatlas-dev.sh
    └── workflow.md

8 directories, 20 files
$
```

Each subdirectory in this repo, except migrate_to_spin2, corresponds to a pod within the workload.
- backup_restore: Daily cron job that performs a backup of the database and files (within /usr/local/labkey/files/) to the global filesystem at /global/cfs/cdirs/metatlas/projects/lims_backups/pg_dump. Also can be used to before data restores.
- db: postgres database
- get-cert: For obtaining a temporary cert from [Let's Encyrpt](https://letsencrypt.org/) for use during testing. Nominally not running.
- labkey: LabKey community edition web application running on top of Apache Tomcat.

Each subdirectory contains a kubernetes .yaml file used to configure a pod. All of the pods except for labkey and backup_restore make use of externally generated container images pulled from [docker hub](https://www.dockerhub.com/). 

## Deployment Instructions

The following instructions can be used to do a new deployment of metatlas LIMS, including a restore of old data from backups, or to update an existing deployment to match the settings in this repo.

1. Install [docker](https://docs.docker.com/get-docker/) or [podman](https://podman.io/getting-started/installation) on your local machine.
2. Git clone this repo to your local machine:
  - `git clone https://github.com/biorack/labkey_deploy`
3. Build and push images to [registry.spin.nersc.gov](https://registry.spin.nersc.gov):
  - `docker login registry.spin.nersc.gov`
  - `./labkey_deploy/build.sh --all`
4. Git clone this repo to a cori login node:
  - `git clone https://github.com/biorack/labkey_deploy`
5. In the root directory of the deploy_labkey repo, create a .secrets file:
  - ```cd labkey_deploy
       touch .secrets
       chmod 600 .secrets
       echo "POSTGRES_PASSWORD=MyPostgresPassWord" > .secrets
       echo "MASTER_ENCRYPTION_KEY=MyLabkeyEncryptionKey" >> .secrets```
6. In the root directory of the deploy_labkey repo, create the following files containing your TLS private key and certificate:
  - .tls.metatlas.nersc.gov.key  (if working with the dev instance, use .tls.metatlas-dev.nersc.gov.key)
  - .tls.metatlas.nersc.gov.pem  (if working with the dev instance, use .tls.metatlas-dev.nersc.gov.pem)
    - The certificate should be PEM encoded, contain the full chain, and be in reverse order (your cert at top to root cert at bottom).
7. Ensure the .tls.key file is only readable by you:
  - `chmod 600 .tls.metatlas.nersc.gov.keys`
8. Run the deployment script: `./deploy.sh --labkey registry.spin.nersc.gov/lims/labkey:YYYY-MM-DD-HH-SS --backup registry.spin.nersc.gov/lims/backup_restore:YYYY-MM-DD-HH-SS`
  - You'll need to pass it flags the location of the labkey and backup_restore docker images on the repos. Set the timestamps to match the tags on registry.spin.nersc.gov. The two images will likely have different timestamps!
  - If doing a new installation, where the persistant volumes do not already contain a populated database and filesystem, then pass the `--new` flag. The `--new` flag will restore backups of both the database and the filesystem where labkey stores files. By default, `--new` uses the most recent backups, but you can use `--timestamp` to select a specific backup. 

## Labkey Upgrade Instructions

1. `cd labkey`
1. Edit `Dockerfile` to have the correct values in these lines:
   ```
   ARG LABKEY_MAJOR_VERSION="23"
   ARG LABKEY_MINOR_VERSION="3"
   ARG LABKEY_PATCH_VERSION="1"
   ARG LABKEY_BUILD_NUM="4"
   ```
   You can find these values by filling out the [Labkey download
   request form](https://www.labkey.com/download-community-edition/)
   and then looking at the URL for the tar.gz download.
1. `./build.sh`
1. The last line of output will container an image tag in the form
   `YYYY-MM-DD-HH-MM`. Copy this value.
1. Go to
   [https://rancher2.spin.nersc.gov/p/c-tmq7p:p-gqfz8/workload/deployment:lims:labkey]
1. Reduce the 'config scale' to 0
1. Wait for the running pod to be fully removed
1. Click the triple-dot button in near the upper right corner of the Ranche2
   web page and then select 'Edit' from the dropdown menu.
1. Replace the tag in the 'Docker image' field
1. Click 'Save' button
1. Go to
   [https://rancher2.spin.nersc.gov/p/c-tmq7p:p-gqfz8/workload/deployment:lims:labkey]
1. Set the 'config scale' to 1
1. Wait for the LabKey pod to come up and be ready. You may want to view the
   pod logs while you wait to see if there are any errors -- see the
   triple-dot menu at the right side of the pod row.
1. Go to [https://metatlas.nersc.gov/] to verify the server is working.
1. Commit and push your changes to this repo, so that the master branch matches
   the current production configuration.
