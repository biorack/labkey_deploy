# metatlas LIMS
Configuration for deploying and running [metatlas.lbl.gov](https://metatlas.lbl.gov/), the LIMS for
the [metabolomics team](https://jgi.doe.gov/our-science/science-programs/metabolomics-technology/)
at [Joint Genome Institute](https://www.jgi.doe.gov/). This LIMS is based on the community
edition of [LabKey](https://www.labkey.org/). The metatlas LIMS is deployed on
[NERSC](http://www.nersc.gov/)'s [SPIN](https://www.nersc.gov/systems/spin/)
platform for running containered services using [Kubernetes](https://kubernetes.io/) via
[Rancher](https://rancher.com/products/rancher/) v2.

A [previous configuration](https://github.com/biorack/labkey_deploy) of the metatlas LIMS was set up
with LabKey's non-embedded web server versions (up to major version 23), whereas this configuration
deploys the embedded web server version (major version 24+). Use these instructions for updating,
deploying, and debugging the LIMS SPIN app as of July, 2024.

## LabKey Version Documentation

LabKey provides [overall installation instuctions](https://www.labkey.org/Documentation/wiki-page.view?name=manualInstall) and [instructions for setting up the required components](https://www.labkey.org/Documentation/wiki-page.view?name=installLinux). But reading those docs is not necessary if deploying from this repo without modification.

## Overview of Repo

The layout of this repo is:

```
$ tree -L 2
.
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
    ├── README.md
    ├── R_smkosina01-lock.yaml
    ├── R_smkosina01.yaml
    ├── R_tidyverse-lock.yaml
    ├── R_tidyverse.yaml
    ├── VERSION
    ├── application.properties
    ├── config
    ├── docker-compose.yml
    ├── entrypoint.sh
    ├── labkey-files.yaml
    ├── labkey.yaml.template
    ├── labkeyServer.jar
    ├── labkey_server.service
    ├── lb.yaml.template
    ├── log4j2.xml
    ├── make_command.sh
    ├── mounts
    ├── python-lock.yaml
    ├── python.yaml
    ├── quickstart_envs.sh
    ├── scripts
    ├── smoke.bash
    ├── src
    ├── startup
    ├── update_lock.sh
    └── xvfb.sh
```

Each subdirectory in this repo corresponds to a pod within each Rancher workload in the
lims-24 SPIN namespace. Each subdirectory contains a kubernetes `.yaml` file(s) used to configure a pod.

- `backup_restore`: Daily cron job that performs a backup of the database and
  files (`/usr/local/labkey/files/` in the container) to the global perlmutter filesystem 
  at `/global/cfs/cdirs/metatlas/projects/lims_backups/pg_dump/lims-24`. Also can be
  used to back up manually on the Rancher interface before data restores.
- `db`: postgres database base docker image
- `labkey`: LabKey community edition web application with an embedded Apache
  Tomcat.

## Conda Environments

The `python.yaml` and `R_*.yaml` files within the `labkey` directory define conda
environments which are made available to the LabKey webserver to run user scripts.
These environments also have corresponding
[lock files](https://github.com/conda/conda-lock) named `*-lock.yaml`. 

If you add or update an environment yaml file, you must run `update_lock.sh example.yaml` 
to generate an updated lock file before deploying the LIMS. To do this:

1. Install the the conda-lock package with `pip install conda-lock`
2. If running on a Mac with Apple's M1/M2 architecture, edit the `update_lock.sh` script to 
include “-p linux-aarch64” flag in the `conda-lock` command if not already there.
3. Run the update lock script on all yaml files that have been added or edited
```
./update_lock.sh R_smkosina01.yaml
./update_lock.sh R_tidyverse.yaml
./update_lock.sh python.yaml
./update_lock.sh ...
```

## Deployment Instructions

The following instructions can be used to do a new deployment of metatlas LIMS, including a restore of old data from backups, or to update an existing deployment to match the settings in this repo.

1. Install [docker](https://docs.docker.com/get-docker/) or [podman](https://podman.io/getting-started/installation) on your local machine.
2. Git clone this repo to your local machine:
  - `git clone https://github.com/biorack/labkey_deploy_embedded`
3. Enter the directory and ensure it matches the structure shown above.
4. Build and push images to [registry.spin.nersc.gov](https://registry.spin.nersc.gov):
  - If building the docker images from a Macbook with Apple's M1/M2 architecture, first install the
[buildx kit](https://www.docker.com/blog/how-to-rapidly-build-multi-architecture-images-with-buildx/) and have it running in your local docker instance. This will allow you to build an image that can be run
on perlmutter AMD architecture.
  - `docker login registry.spin.nersc.gov`
  - `cd labkey_deploy_embedded/labkey/; ./make_command.sh`
5. Git clone this repo to a perlmutter login node:
  - `git clone https://github.com/biorack/labkey_deploy_embedded`
6. In the root directory of the repo, create a .secrets file:
  ```cd labkey_deploy_embedded
       touch .secrets
       chmod 600 .secrets
       echo "POSTGRES_PASSWORD=MyPostgresPassWord" > .secrets
       echo "MASTER_ENCRYPTION_KEY=MyLabkeyEncryptionKey" >> .secrets
  ```
  - Secrets can be identified within the existing SPIN app by starting a Rancher terminal and echoing the
  environmental variables above.
7. In the root directory of the repo, create the following files containing your TLS private key and certificate:
  - .tls.metatlas.lbl.gov.key  (if working with the dev instance, use .tls.metatlas-dev.lbl.gov.key)
  - .tls.metatlas.lbl.gov.pem  (if working with the dev instance, use .tls.metatlas-dev.lbl.gov.pem)
    - The certificate should be PEM encoded, contain the full chain, and be in reverse order (your cert at top to root cert at bottom).
    - To obtain a certificate for metatlas.lbl.gov, follow [these instructions](https://code.jgi.doe.gov/-/snippets/27).
8. Ensure the .tls.key file is only readable by you:
  - `chmod 600 .tls.metatlas.lbl.gov.key`
9. Run the deployment script from the perlmutter login node: 
  - `<repo_dir>/deploy.sh --labkey registry.nersc.gov/m2650/lims/labkey/community:labkeyVERSION_YYYY-MM-DD-HH-SS --backup registry.nersc.gov/m2650/lims/labkey/community:backup_restore_YYYY-MM-DD-HH`
    - You'll need to pass flags for the correct tags of the labkey and backup_restore docker images. Set the timestamps to match the tags on registry.spin.nersc.gov under the [metabolomics project directory](https://registry.nersc.gov/harbor/projects/69/repositories/lims%2Flabkey%2Fcommunity)
    - If doing a new installation, where the persistant volumes do not already contain a populated database and filesystem, then pass the `--new` flag. The `--new` flag will restore backups of both the database and the filesystem where labkey stores files. By default, `--new` uses the most recent backups, but you can use `--timestamp` to select a specific backup. See `deploy.sh` for more details on flags.

## Labkey Upgrade Instructions

1. Enter the repo dir on perlmutter and go to the labkey subdir:
  - `cd labkey_deploy_embedded/labkey`
2. Edit the `make_command.sh` so that:
  - The `LABKEY_VERSION` variable is the new version for which you're trying to create an image (e.g., `LABKEY_VERSION=24.3.4-6`).
  - The `NEW_DOWNLOAD` variable is 1 if you're downloading the LabKey software from online for the update.
  This will run `scripts/download_lims_distribution.sh` that downloads the LIMS distribution,
  creates the correct directory structure, and moves the required files their
  location in the repo before building the image. Set `NEW_DOWNLOAD` variable to 0 to skip this process
  (e.g., if you're troublshooting and already have the LabKey files downloaded/moved into the repo).
  - If you do not know it, you can find the LabKey version number by filling out the [Labkey download request form](https://www.labkey.com/download-community-edition/) and then looking at the URL for the `tar.gz` download.
3. `./make_command.sh`
  - This command will run through the `labkey` Makefile and run a login, build, tag, push sequence
  to containerize the labkey docker image on the NERSC repository
4. If necessary (e.g., if upgrading to a new postgres version), also move into the 
  `labkey_deploy_embedded/backup_restore/` directory and run `./make_command.sh` to update the backup container.
5. Go to the [LabKey pod page](https://rancher2.spin.nersc.gov/dashboard/c/c-tmq7p/explorer/apps.deployment/lims-24/labkey#pods) in the lims-24 namespace
6. Reduce the 'Scale' to 0 to spin down the pod running LIMS
7. Wait for the running pod to be fully removed
8. Click the triple-dot button in near the upper right corner of the Rancher2
   web page and then select 'Edit Config' from the dropdown menu.
9. Replace the image tag (e.g., labkey24.3.4-6_2024-06-24-11-40) in the 'Container image' field with
  the tag from the newer build
10. Click 'Save' button
11. Go back to the pod page and dial up the 'Scale' to 1
12. Wait for the LabKey pod to come up and be ready. You may want to view the
   pod logs while you wait to see if there are any errors -- see the
   triple-dot menu at the right side of the pod row.
13. Go to [metatlas.lbl.gov](https://metatlas.lbl.gov/) to verify the server is working.
14. Commit and push your changes to this repo, so that the master (main) branch matches
   the current production configuration.
