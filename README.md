# JGI Metabolomics LIMS

This repo contains instructions for configuring, deploying, and running the LIMS for the 
[metabolomics team](https://jgi.doe.gov/our-science/science-programs/metabolomics-technology/)
at [Joint Genome Institute](https://www.jgi.doe.gov/). This LIMS is hosted at [metatlas.lbl.gov](https://metatlas.lbl.gov/) and is based on the community
edition of [LabKey](https://www.labkey.org/). The metatlas LIMS is deployed and hosted on
[NERSC](http://www.nersc.gov/)'s [SPIN](https://www.nersc.gov/systems/spin/)
platform for running containered services using [Kubernetes](https://kubernetes.io/) via
[Rancher](https://rancher.com/products/rancher/) (v2).

A [previous configuration](https://github.com/biorack/labkey_deploy) of the metatlas LIMS was set up
with LabKey's non-embedded web server versions (up to major version 23), whereas this configuration
deploys the embedded web server version (major version 24+). Use these instructions for updating,
deploying, and debugging the LIMS SPIN app as of July, 2024. Please see previous commit history of this
repository for deploying the old LabKey LIMS v23.

## LabKey Version Documentation

LabKey provides [overall installation instuctions](https://www.labkey.org/Documentation/wiki-page.view?name=manualInstall) and [instructions for setting up the required components](https://www.labkey.org/Documentation/wiki-page.view?name=installLinux). But reading those docs is not necessary if deploying from this repo without modification.

## Overview of this Repo

The layout of the github repository for controlling the LIMS is:

```
$ tree -L 2
.
├── LICENSE
├── README.md
├── backup_restore
│   ├── Dockerfile
│   ├── Makefile
│   ├── backup.yaml.template
│   ├── bin
│   ├── build.sh
│   ├── make_command.sh
│   ├── restore-root.yaml.template
│   └── restore.yaml.template
├── db
│   ├── db-data.yaml
│   └── db.yaml
├── deploy.sh
└── labkey
    ├── Dockerfile
    ├── LICENSE
    ├── Makefile
    ├── R_smkosina01-lock.yaml
    ├── R_smkosina01.yaml
    ├── R_tidyverse-lock.yaml
    ├── R_tidyverse.yaml
    ├── VERSION
    ├── application.properties
    ├── docker-compose.yml
    ├── entrypoint.sh
    ├── labkey-files.yaml
    ├── labkey.yaml.template
    ├── labkey_server.service
    ├── lb.yaml.template
    ├── log4j2.xml
    ├── make_command.sh
    ├── python-lock.yaml
    ├── python.yaml
    ├── scripts
    ├── startup
    ├── update_lock.sh
    └── xvfb.sh
```

Each subdirectory corresponds to a pod within each Rancher production workload in the
lims-24 SPIN namespace and contains a kubernetes `.yaml` file(s) used to configure the pod.
The major components of the system are the following docker images which run in the pods:

- `backup_restore`: Daily cron job that performs a backup of the database and
  files (`/usr/local/labkey/files/` in the container) to the global perlmutter filesystem 
  at `/global/cfs/cdirs/metatlas/projects/lims_backups/pg_dump/lims-24`. Also used during
  a new deployment to restore the database from the backup archive.
- `db`: postgres database base docker image
- `labkey`: LabKey community edition web application with an embedded Apache
  Tomcat.

# Redeploying an Existing LIMS Instance in Rancher

If the LIMS or an associated pod/service stop running (i.e., software instability, NERSC maintenance, etc.)
and it is not necessary to update any software, you can redeploy the existing workloads via the Rancher2
interface:

## Manual Redeploy

1. Go to the [LabKey pod page](https://rancher2.spin.nersc.gov/dashboard/c/c-tmq7p/explorer/apps.deployment/lims-24/labkey#pods) on Rancher2 in the m2650 project and the lims-24 namespace
2. Reduce the 'Scale' to 0 to spin down the pod running LIMS (`labkey`) by clicking next to the colored bar
3. Wait for the running pod to be fully offline
4. If you need to use a different version of the docker image, click the triple-dot button in near the upper
 right corner of the Rancher2 web page and then select 'Edit Config' from the dropdown menu.
  - Replace the image tag (e.g., labkey24.3.4-6_2024-06-24-11-40) in the 'Container image' field with
  the tag from the newer build
  - Click 'Save' button
5. On the pod page, dial up the 'Scale' to 1 by clicking next to the colored bar
6. Wait for the LabKey pod to come up and be ready. You may want to view the
   pod logs while you wait to see if there are any errors -- see the
   triple-dot menu at the right side of the pod row.
7. Go to [metatlas.lbl.gov](https://metatlas.lbl.gov/) to verify the server is working.

# Updating the LIMS and Redeploying

Occasionally, the LabKey, postgres, or other associated software (e.g., python/R libraries) need to be
upgraded or updated. Since this typically involves changing the underlying docker images or their
dependents, a sequence of edits, repo commits, image building/pushing, and SPIN deployment must be followed
to bring the system back online from scratch.

## Conda Environments

The `python.yaml` and `R_*.yaml` files within the `labkey` directory define conda
environments which are made available to the LabKey webserver to run user scripts.
These environments also have corresponding
[lock files](https://github.com/conda/conda-lock) named `*-lock.yaml`. 

If no changes are required to python/R environments for the new deployment, you can skip
this section.

If you add or update an environment yaml file (e.g., to add new libraries or change existing library
versions), you must run `update_lock.sh example.yaml` 
to generate an updated lock file before deploying the LIMS. To do this:

1. Install the the conda-lock package with `pip install conda-lock`
2. If running on a Mac with Apple's M1/M2 architecture, edit the `update_lock.sh` script to 
include “-p linux-aarch64” flag in the `conda-lock` command (if not already there).
3. Run the update lock script on all yaml files that have been added or edited
```
./update_lock.sh R_smkosina01.yaml
./update_lock.sh R_tidyverse.yaml
./update_lock.sh python.yaml
./update_lock.sh ...
```

## Creating Docker Images for SPIN Pods

The SPIN pods that run the LIMS (`labkey`) and the data backup system (`backup_restore`) are set up from
images built on your local machine and pushed to the 
[NERSC container registry](https://registry.spin.nersc.gov).

While these images already exist in the registry, to upgrade the LabKey or postgres software versions that
run `labkey` and `backup_restore`, respectively, it is necessary to rebuild the images.

Follow these general steps to build, tag, and push new images, then see the sections below for
specific instructions for `labkey` and `backup_restore`.

1. Install [docker](https://docs.docker.com/get-docker/) or [podman](https://podman.io/getting-started/installation) on your local machine.
2. Git clone (or pull) this repo to your local machine:
  - `git clone https://github.com/biorack/labkey_deploy`
3. Enter the repo directory and ensure it matches the structure shown in the `tree -L 2` command above.
4. If building the docker images from a Macbook with Apple's M1/M2 architecture, first install the
[buildx kit](https://www.docker.com/blog/how-to-rapidly-build-multi-architecture-images-with-buildx/) and have it running in your local docker desktop. This will allow you to build an image that can be run
on perlmutter AMD architecture. The `docker build` instructions described below will detect if you are
running from a machine with Apple arch and use the `buildx kit` accordingly.

### Labkey Image

1. Enter the labkey subdirectory (`cd labkey_deploy/labkey/`)
2. Edit the `make_command.sh` so that:
  - The `LABKEY_VERSION` flag matches the new version for which you're trying to create an image (e.g., `LABKEY_VERSION=24.3.4-6`).
  - The `NEW_DOWNLOAD` variable is 1 if you're downloading the LabKey software from online for the update.
  This will run `scripts/download_lims_distribution.sh` that downloads the LIMS distribution,
  creates the correct directory structure, and moves the required files their
  location in the repo before building the image. Set `NEW_DOWNLOAD` variable to 0 to skip this process
  (e.g., if you're troublshooting and already have the LabKey files downloaded/moved into the repo).
  - If you do not know it, you can find the LabKey version number by filling out the [Labkey download request form](https://www.labkey.com/download-community-edition/) and then looking at the URL for the `tar.gz` download.
3. Run `docker login registry.spin.nersc.gov` and enter your credentials for the registry.
4. Run `./make_command.sh`
  - This command will run through the `labkey` dir Makefile and run a login, build, tag, push sequence
  to containerize the labkey docker image on the NERSC repository.
  - If `NEW_DOWNLOAD` is set to 1, you should see the LabKey software curl download.
  - Then you should see the docker image get built, tagged, and pushed. Navigate to the NERSC registry's
  [metabolomics project directory](https://registry.nersc.gov/harbor/projects/69/repositories/lims%2Flabkey%2Fcommunity) and ensure your tagged image is present.
  - Note on July 26, 2024: An error occured during the docker build phase that was solved by changing the GID and UID for
  mamba from 1000 to 999. If this occurs in the future, you made need to change to another value.

### Backup/Restore Image

1. Enter the labkey subdirectory (`cd labkey_deploy/backup_restore/`)
2. Optionally, edit the `Dockerfile` and update the base image in `FROM postgres:15-alpine`. If you do
update this base image, you should edit the repo's `db/db.yaml` file `image:` line to match.
3. Run `./make_command.sh`
  - This command will run through the `backup_restore` dir Makefile and run a login, build, tag, push 
  sequence to containerize the backup+restore docker image on the NERSC repository.
  - You should see the docker image get built, tagged, and pushed. Navigate to the NERSC registry's
  [metabolomics project directory](https://registry.nersc.gov/harbor/projects/69/repositories/lims%2Flabkey%2Fcommunity) and ensure your tagged image is present.

### Update repository

Once the software update(s), local image building, and push to the NERSC registry is completed, push your
local repo changes to `labkey_deploy` main (or your branch, then merge with main).

## Deployment Instructions

Now that images are updated, deploy the LIMS in SPIN.

The LIMS, backup+restore, postgres db, and load balancer are started up in SPIN using the kubernetes-based 
deploy script `deploy.sh` in the main repo directory. The deployment must happen on a NERSC system 
(e.g., a perlmutter login node).

1. Git clone (or pull) this repo on perlmutter:
  - `git clone https://github.com/biorack/labkey_deploy`
2. In the root directory of the repo, create a .secrets file:
  ```
  cd labkey_deploy
       touch .secrets
       chmod 600 .secrets
       echo "POSTGRES_PASSWORD=MyPostgresPassWord" > .secrets
       echo "MASTER_ENCRYPTION_KEY=MyLabkeyEncryptionKey" >> .secrets
  ```
  - Secrets can be identified within the existing SPIN app by starting a Rancher terminal and echoing the
  environmental variables above, or on perlmutter in the current deployment location.
3. In the root directory of the repo, create the following files containing your TLS private key and
certificate:
  - .tls.metatlas.lbl.gov.key  (if working with the dev instance, use .tls.metatlas-dev.lbl.gov.key)
  - .tls.metatlas.lbl.gov.pem  (if working with the dev instance, use .tls.metatlas-dev.lbl.gov.pem)
    - The certificate should be PEM encoded, contain the full chain, and be in reverse order (your cert at top to root cert at bottom).
    - To obtain a certificate for metatlas.lbl.gov, follow [these instructions](https://code.jgi.doe.gov/-/snippets/27).
4. Ensure the .tls.key file is only readable by you, e.g.:
  - `chmod 600 .tls.metatlas.lbl.gov.key`
5. Run the deployment script from the root directory of the repo on the perlmutter login node: 
  - `deploy.sh --labkey registry.nersc.gov/m2650/lims/labkey/community:labkeyVERSION_YYYY-MM-DD-HH-SS --backup registry.nersc.gov/m2650/lims/labkey/community:backup_restore_YYYY-MM-DD-HH`
    - You'll need to pass flags for the correct tags of the `labkey` and `backup_restore` docker images. 
    Set the version and timestamps to match the tags in the registry (these are also printed locally after
    running `make_command.sh`).
    - If deploying when the system is inactive (i.e., no pods are running and/or the persistant volumes
    do not already contain a populated database and filesystem), pass the `--new` flag. The `--new` flag
    will restore backups of both the database and the filesystem where labkey stores files. By default,
    `--new` uses the most recent backups, but you can use `--timestamp` to select a specific backup. See
    `deploy.sh` for more details on flags, including deployment to the SPIN production cluster (default). 
    vs. development cluster.
6. While the deploy runs, you should see useful messages printed to standard output on the login node, and
  you can watch the restore, db mounting, and LabKey software boot roll out in order on Rancher.
7. When successfully deployed, the LIMS should be reachable at [metatlas.lbl.gov](metatlas.lbl.gov) and
  all the pods should have ready status in Rancher. Troubleshooting can be done in Rancher by clicking the
  three-dot button to the right of a workload and executing a shell or looking at logs.
8. It is also a good idea to manually run the backup cronjob from Rancher and check that it is working
  properly by looking at the backup location (currently `/global/cfs/cdirs/metatlas/projects/lims_backups/pg_dump/lims-24`).
