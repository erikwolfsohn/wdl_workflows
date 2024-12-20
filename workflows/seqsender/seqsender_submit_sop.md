# seqsender_submit: Terra submission workflow for GISAID, BioSample, and SRA

## About:
This workflow uses metadata created by the seqsender_submission_prep workflow to submit assemblies and raw reads to public repositories. It currently supports all available BioSample packages for submission to NCBI BioSample/SRA, as well as SARS-CoV-2 submission to GISAID.

The workflow can be run in two modes:
- submit: submit data to the selected repositories
- status: check the status of an existing submission

## Terra workflow configuration
### Inputs:
| Task Name | Variable | Type | D[escription&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;| Example&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|Default Value | Status&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; |
|:---------- |:--------- |:----- |:------------ |:-------- |:------------- |:------- |
|`seqsender`|`config_yaml`|`File`|A YAML configuration file containing information and credentials for each repository you intend to submit to.|See example config.yaml below.|`None`|Required|
|`seqsender`|`mode`|`String`|Mode selection: `"submit"` or `"status"`. Submit data to public repositories or check the status of an existing submission.|`"submit"`|`None`|Required|
|`seqsender`|`concatenated_fasta`|`File`|Concatenated FASTA file for submission to GISAID or GenBank.|`this.seqsender_concatenated_fasta`|`None`|Optional|
|`seqsender`|`gisaid_cov_cli`|`File`|GISAID covCLI executable, required if submitting SARS-CoV-2 assemblies to GISAID.|`workspace.seqsender_gisaid_covCLI`|`None`|Optional<br>*Required when submitting SARS-CoV-2 assemblies to GISAID.*|
|`seqsender`|`have_fasta`|`Boolean`|Indicate whether you have a FASTA for GISAID/GenBank submission.|`true`|`false`|Optional|
|`seqsender`|`metadata_file`|`File`|Metadata for seqsender repository submission - generated by running seqsender_submission_prep.|`this.seqsender_metadata`|`None`|Optional<br>*Required when workflow mode is "submit".*|
|`seqsender`|`organism`|`String`|Mode selection: `"COV"` or `"OTHER"`. Enable organism-specific submission options.|`"OTHER"`|`"COV"`|Optional|
|`seqsender`|`submission_name`|`String`|Unique name for your submission. When running in status mode, this should match the name of submission you are checking.|`this.sample_set_id`|`"public_health"`|Optional<br>*Setting this to `tablename_set_id` will make it easier to track submission status.*|
|`seqsender`|`submit_to_biosample`|`Boolean`|Indicate if you will be submitting to BioSample.|`true`|`false`|Optional|
|`seqsender`|`submit_to_gisaid`|`Boolean`|Indicate if you will be submitting to GISAID.|`true`|`false`|Optional|
|`seqsender`|`submit_to_sra`|`Boolean`|Indicate if you will be submitting to SRA.|`true`|`false`|Optional|
|`seqsender`|`test`|`Boolean`|Indicate whether data will be submitted to the NCBI test or production environment.|`false`|`true`|Optional|
|`seqsender`|`submission_log`|`File`|Logfile generated after submitting data|`this.seqsender_submit_log`|`None`|Optional<br>*Required when running workflow in `"status"` mode.*|
|`seqsender`|`submission_tgz`|`File`|Entire output folder generated during seqsender submission.|`this.seqsender_submission_tgz`|`None`|Optional<br>*Required when running workflow in `"status"` mode.*|

### Outputs:
| Task Name | Variable | Type | Description&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|
|:---------- |:--------- |:----- |:------------ |
|`seqsender`|`seqsender_status_log`|`File`|Logfile generated when running workflow in `"status"` mode.|
|`seqsender`|`seqsender_status_results`|`File`|Entire output folder generated when running workflow in `"status"` mode.|
|`seqsender`|`seqsender_status_summary`|`File`|Submission summary generated when running workflow in `"status"` mode. Contains submission IDs and accessions (if assigned) for each repository|
|`seqsender`|`seqsender_submission_name`|`String`|Submission name specified when running workflow in `"submit"` mode.|
|`seqsender`|`seqsender_submit_log`|`File`|Logfile generated when running workflow in `"submit"` mode.|
|`seqsender`|`seqsender_submit_results`|`File`|Entire output folder generated when running workflow in `"submit"` mode.|
|`seqsender`|`seqsender_submit_summary`|`File`|Submission summary generated when running workflow in `"submit"` mode. Contains submission IDs and accessions (if assigned) for each repository|

## Example Configuration Files:
Submission config.yaml:
An config.yaml template can be generated from the [seqsender wizard.](https://cdcgov.github.io/seqsender/) Below is an example config.yaml for submitting SARS-CoV-2 data to BioSample, SRA, and GISAID.

```
Submission:
  NCBI:
    Username: your_NCBI_username
    Password: your_NCBI_password
    Submission_Position:
    Spuid_Namespace: YOURNAMESPACE
    BioSample_Package: SARS-CoV-2.cl.1.0
    Publication_Title: SARS-CoV-2 Surveillance
    Publication_Status: Unpublished
    Specified_Release_Date:
    Link_Sample_Between_NCBI_Databases: on
    Description:
      Title: SARS-CoV-2 Surveillance
      Comment: SARS-CoV-2 Genomic Surveillance
      Organization:
        Role: owner
        Type: institute
        Name: YOUR_LAB
        Address:
          Affil: Example University School of Medicine
          Div: Your State Public Health Laboratory
          Street: 12345 Example Street
          City: Washington
          Sub: DC
          Postal_Code: 22101
          Country: USA
          Email: institution_email@your_institution.org
          Phone: 123-456-7890
        Submitter:
          Email: submitter_email@your_institution.org
          Alt_Email: alternate_email@your_institution.org
          Name:
            First: Jane
            Last: Doe
  GISAID:
    Client-Id: TEST-EA76875B00C3
    Username: your_GISAID_username
    Password: your_GISAID_password
    Submission_Position: