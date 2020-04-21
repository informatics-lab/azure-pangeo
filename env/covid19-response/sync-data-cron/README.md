To get the cron running you need a SAS (shared access signature URL for the AZURE blob. Can be read only). 

Create a file `env/covid19-response/sync-data-cron/SAS.txt` and put just this in it (use a full url style one)

Then create secret from it:

`kubectl -n covid19-response create secret generic sync-sas  --from-file=env/covid19-response/sync-data-cron/SAS.txt`

Then deploy

`kubectl -n covid19-response apply -f env/covid19-response/update-ancillary-data-cron.yaml`
