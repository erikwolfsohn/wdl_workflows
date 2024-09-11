# seqsender_submission_prep: submission preparation for the seqsender workflow

## About:
This workflow formats input from a Terra.bio table into a seqsender-compatible metadata file, which can be used to submit sequences to NCBI and GISAID repositories. It currently supports all available BioSample packages for submission to NCBI BioSample/SRA, as well as SARS-CoV-2 submission to GISAID. 

By default, this workflow searches for columns in the Terra metadata table that match the names of the columns required by each repository. However, this behavior can be customized using the configuration files as described below.

## Terra workflow configuration
### Inputs:
| Task Name | Variable | Type | Description&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;| Example&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|Default Value | Status |
|:---------- |:--------- |:----- |:------------ |:-------- |:------------- |:------- |
|`seqsender_submission_prep`|`biosample_schema_name`|`String`|The name of the NCBI BioSample schema. |`"SARS-CoV-2.cl.1.0.xml"`| `None`|Required|
|`seqsender_submission_prep`|`project_name`|`String`|The name of the Terra billing project where submissions are being sent from.|`"terra-state-phl"`<br>This can be found in the URL of your Terra workspace: app.terra.bio/#workspaces/**terra-state-phl**/COVID-STATE-PHL/|`None`|Required|
|`seqsender_submission_prep`|`repository_column_map_csv`|`File`|A CSV which matches column names in your Terra table to the corresponding column names expected by each repository.|Example: collecting_lab in your Terra table corresponds to collected_by in NCBI BioSample and covv_orig_lab in GISAID&#10;`terra,gen,biosample,sra,gisaid`&#10;`collecting_lab,,collected_by,,covv_orig_lab`|`None`|Required|
|`seqsender_submission_prep`|`repository_selection`|`String`|Comma separated string of repositories to prepare submission metadata for. Valid options: BioSample (bs), SRA (sra), GISAID (gs)| `"bs,sra,gs"`|`None`|Required|
|`seqsender_submission_prep`|`sample_names`|`Array[String]`|The samples you select for submission from your Terra table|`this.samples.sample_id`|`None`|Required|
|`seqsender_submission_prep`|`static_metadata_csv`|`File`|A CSV which allows you to specify metadata values that are not in your Terra table, and will be identical across the entire submission.|Example: all sequences submitted will have the BioSample location USA:NV, all SRA files will be located in the cloud, and all will have the GISAID assembly method Clear Labs BIP<br>`db,key,value`<br>`bs,geo_loc_name,USA:CA`<br>`sra,file_location,cloud`<br>`gs,covv_assembly_method,Clear Labs BIP`|`None`|Required|
|`seqsender_submission_prep`|`table_name`|`String`|Name of the Terra table where submissions are being sent from.|`"sample"`|`None`|Required|
|`seqsender_submission_prep`|`workspace_name`|`String`|Name of the Terra workspace where submissions are being sent from.|`"COVID-STATE-PHL"`<br>This can be found in the URL of your Terra workspace: app.terra.bio/#workspaces/terra-state-phl/**COVID-STATE-PHL**/|`None`|Required|
|`seqsender_submission_prep`|`sra_transfer_gcp_bucket`|`String`|Cloud bucket where raw read files will be staged for upload to SRA|`"gs://sra_transfer_bucket/"`|`None`|Optional|
|`seqsender_submission_prep`|`check_coverage`|`Boolean`|Check sequence coverage before preparing for submission.|`True`|`False`|Optional|
|`seqsender_submission_prep`|`threshold_min_coverage`|`Int`|If check_coverage is true, specify minimum coverage to qualify for submission|`85`|`85`|Optional|
|`seqsender_submission_prep`|`coverage_column`|`String`|If check_coverage is true, specify the Terra table column containing assembly coverage metadata|`"clearlabs_assembly_coverage"`|`None`|Optional|
|`seqsender_submission_prep`|`check_seq_length`|`Boolean`|Check sequence length before preparing for submission.|`True`|`False`|Optional|
|`seqsender_submission_prep`|`threshold_max_seq_length`|`Int`|If check_seq_length is true, specify max sequence length to qualify for submission|`50000`|`100000`|Optional|
|`seqsender_submission_prep`|`seq_length_column`|`String`|If check_seq_length is true, specify the Terra table column containing sequence length metadata|`"seq_length"`|`None`|Optional|
|`seqsender_submission_prep`|`check_contigs`|`Boolean`|Check number of contigs before preparing for submission.|`True`|`False`|Optional|
|`seqsender_submission_prep`|`threshold_max_contigs`|`Int`|If check_contigs is true, specify max contigs to qualify for submission|`300`|`200`|Optional|
|`seqsender_submission_prep`|`contigs_column`|`String`|If check_contigs is true, specify the Terra table column containing num contigs metadata|`"num_contigs"`|`None`|Optional|

### Outputs:
| Task Name | Variable | Type | Description&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|
|:---------- |:--------- |:----- |:------------ |
|`seqsender_submission_prep`|`seqsender_concatenated_fasta`|`File`|Concatenated FASTA file for submission to GISAID and GenBank|
|`seqsender_submission_prep`|`seqsender_metadata`|`File`|Metadata file for seqsender repository submission|

## Example Configuration Files:
repository_column_map_csv
```
terra,gen,biosample,sra,gisaid
library_id,,,library_name,
clearlabs_assembly_coverage,,,,covv_coverage
collecting_lab,,collected_by,,covv_orig_lab
collecting_lab_address,,,,covv_orig_lab_addr
submitting_lab,,,,covv_subm_lab
submitting_lab_address,,,,covv_subm_lab_addr
clearlabs_fastq_gz,,,file_1,
clearlabs_fasta,,,,fasta_column
seq_platform,,,platform,covv_seq_technology
submission_id,,,sample_name,
entity_id_copy,,sample_name,,
purpose_of_sequencing,,,,covv_sampling_strategy
submission_id,sequence_name,,,
```
static_metadata_csv
```
db,key,value
bs,geo_loc_name,USA:CA
bs,host,Homo sapiens
bs,host_disease,COVID-19
bs,isolate_prefix,SARS-CoV-2/human
sra,file_location,cloud
sra,design_description,Whole genome sequencing of SARS-CoV-2
gs,covv_assembly_method,Clear Labs BIP
gs,covv_patient_status,unknown
gs,covv_type,betacoronavirus
gs,covv_passage,original
gs,covv_host,Human
gs,virus_prefix,hCoV-19
gs,covv_comment,
gs,comment_type,
gs,covv_consortium,
gs,covv_outbreak,
gs,covv_last_vaccinated,
gs,covv_add_location,
gs,covv_add_host_info,
gs,covv_specimen,
gs,covv_provider_sample_id,
gs,covv_subm_sample_id,
gs,covv_treatment,
gs,covv_patient_age,unknown
gs,covv_gender,unknown
gen,organism,Severe acute respiratory syndrome coronavirus 2
gen,bioproject,PRJNA000000
```

