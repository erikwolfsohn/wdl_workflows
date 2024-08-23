import xml.etree.ElementTree as ET
from typing import Optional, Tuple
import numpy as np
import pandas as pd
from datetime import datetime
import json


def remove_nas(entity_id: str, table: pd.DataFrame, required_metadata: list[str]) -> Tuple[pd.DataFrame, pd.DataFrame]:
	table.replace(r'^\s+$', np.nan, regex=True) 
	excluded_samples = table[table[required_metadata].isna().any(axis=1)] 
	excluded_samples.set_index(entity_id.lower(), inplace=True) 
	excluded_samples = excluded_samples[excluded_samples.columns.intersection(required_metadata)] 
	excluded_samples = excluded_samples.loc[:, excluded_samples.isna().any()] 
	table.dropna(subset=required_metadata, axis=0, how='any', inplace=True) 

	return table, excluded_samples


def format_location(row: str) -> str:
	return f"{row['continent']}/{row['country']}/{row['state']}/{row['county']}"

def format_gisaid_virus_name(row: str) -> str:
	try:
		year = datetime.strptime(row['collection_date'], '%Y-%m-%d').year
	except ValueError:
		year = None
		
	return f"{row['virus_prefix']}/{row['country']}/{row['submission_id']}/{year}"


def format_biosample_isolate_name(row: str) -> str:
	try:
		year = datetime.strptime(row['collection_date'], '%Y-%m-%d').year
	except ValueError:
		year = None
		
	return f"{row['isolate_prefix']}/{row['country']}/{row['sample_name']}/{year}"


def filter_table_by_biosample(table: pd.DataFrame, biosample_schema: str, static_metadata: pd.DataFrame, repository_column_map: pd.DataFrame, entity_id: str) -> Tuple [pd.DataFrame, list, list]:
	
	table = table.copy()
	
	tree = ET.parse(biosample_schema)
	root = tree.getroot()

	mandatory_list = []
	optional_list = []

	for attribute in root.findall('.//Attribute'):
		use = attribute.get('use')
		name = attribute.find('HarmonizedName').text if attribute.find('HarmonizedName') is not None else "Unknown"


		if use == 'mandatory':
			mandatory_list.append(name)
		elif use == 'optional': 
			optional_list.append(name)
	

	mandatory_list.append(entity_id)
	mandatory_list.append('sample_name')

	try:
		mandatory_list.remove('collection_date')
	except ValueError:
		print('Specimen is missing a collection date. It will probably fail submission.')


	all_attributes = mandatory_list + optional_list

	for index, row in static_metadata[static_metadata['db'].isin(['bs'])].iterrows():
		table[row['key']] = row['value']

	rename_dict = repository_column_map.set_index('terra')['biosample'].dropna().to_dict()
	table.rename(columns=rename_dict,inplace = True)

	# handle errors here
	columns_needed = ['isolate_prefix','sample_name', 'collection_date']
	if all(column in table.columns for column in columns_needed):
		table['isolate'] = table.apply(format_biosample_isolate_name, axis = 1)

	missing_mandatory = list(set(mandatory_list) - set(table.columns))


	filtered_table_df = table[[col for col in table.columns if col in all_attributes]]

	if missing_mandatory:
		print("Your Terra table is missing the following required attributes for BioSample submission: " + str(missing_mandatory))
	
	remove_nas(entity_id, filtered_table_df, mandatory_list)
	filtered_table_df.columns = ['bs-' + col for col in filtered_table_df.columns]
	return filtered_table_df, missing_mandatory, mandatory_list

def filter_table_by_sra(table: pd.DataFrame, static_metadata: pd.DataFrame, repository_column_map: pd.DataFrame, entity_id: str, outdir: str, cloud_uri: Optional[str] = None) -> Tuple [pd.DataFrame, list, list]:
	table = table.copy()

	mandatory_list = [entity_id, "sample_name", "library_name", "library_strategy", "library_source", "library_selection", "library_layout", "platform", "instrument_model", "design_description", "file_1", "platform","file_location"]
	optional_list = ["file_2","file_3","file_4","assembly","fasta_file", "biosample_accession"]
	

	all_attributes = mandatory_list + optional_list
	for index, row in static_metadata[static_metadata['db'].isin(['sra'])].iterrows():
		table[row['key']] = row['value']

	rename_dict = repository_column_map.set_index('terra')['sra'].dropna().to_dict()
	table.rename(columns=rename_dict, inplace = True)

	missing_mandatory = list(set(mandatory_list) - set(table.columns))
	
	if missing_mandatory:
		print("Your Terra table is missing the following required attributes for SRA submission: " + str(missing_mandatory))

	filtered_table_df = table[[col for col in table.columns if col in all_attributes]]
	remove_nas(entity_id, filtered_table_df, mandatory_list)

	filtered_table_df.columns = ['sra-' + col for col in filtered_table_df.columns]


	filtered_table_df["sra-file_1"].to_csv(f'{outdir}/filepaths.csv', index=False, header=False) 
	if cloud_uri:
		filtered_table_df["sra-file_1"] = filtered_table_df["sra-file_1"].map(lambda filename: filename.split('/').pop())
		filtered_table_df["sra-file_1"] = filtered_table_df["sra-file_1"].map(lambda filename: cloud_uri + filename if pd.notna(filename) else filename)
	if "sra-file_2" in filtered_table_df.columns:  
		filtered_table_df["sra-file_2"].to_csv(f'{outdir}/filepaths.csv', mode='a', index=False, header=False)
		if cloud_uri:
			filtered_table_df["sra-file_2"] = filtered_table_df["sra-file_2"].map(lambda filename2: filename2.split('/').pop())
			filtered_table_df["sra-file_2"] = filtered_table_df["sra-file_2"].map(lambda filename2: cloud_uri + filename2 if pd.notna(filename2) else filename2)

	return filtered_table_df, missing_mandatory, mandatory_list

def filter_table_by_gisaid_cov(table: pd.DataFrame, static_metadata: pd.DataFrame, repository_column_map: pd.DataFrame, entity_id: str, outdir: str) -> Tuple [pd.DataFrame, list, list]:
	table = table.copy()
	
	mandatory_list = [entity_id, 'fasta_column', 'submission_id', 'sample_name', 'covv_type', 'covv_passage', 'covv_location', 'covv_host', 'covv_sampling_strategy', 'covv_gender', 'covv_patient_age', 'covv_seq_technology', 'covv_assembly_method', 'covv_coverage', 'covv_orig_lab', 'covv_orig_lab_addr', 'covv_subm_lab', 'covv_subm_lab_addr']

	optional_list = ['covv_add_location', 'covv_add_host_info', 'covv_specimen', 'covv_outbreak', 'covv_last_vaccinated', 'covv_treatment', 'covv_provider_sample_id', 'covv_consortium','covv_subm_sample_id', 'covv_patient_status', 'covv_comment', 'comment_type']
	
	all_attributes = mandatory_list + optional_list

	for index, row in static_metadata[static_metadata['db'].isin(['gs'])].iterrows():
		table[row['key']] = row['value']

	rename_dict = repository_column_map.set_index('terra')['gisaid'].dropna().to_dict()
	table.rename(columns=rename_dict, inplace = True)

	columns_needed = ['virus_prefix','submission_id', 'collection_date']
	if all(column in table.columns for column in columns_needed):
		table['sample_name'] = table.apply(format_gisaid_virus_name, axis = 1)

	columns_needed = ['continent', 'country', 'state', 'county']
	if all(column in table.columns for column in columns_needed):
		table['covv_location'] = table.apply(format_location, axis = 1)

	
	missing_mandatory = list(set(mandatory_list) - set(table.columns))

	if missing_mandatory:
		print("Your Terra table is missing the following required attributes for GISAID covCLI submission: " + str(missing_mandatory))	

	filtered_table_df = table[[col for col in table.columns if col in all_attributes]]

	remove_nas(entity_id, filtered_table_df, mandatory_list)
	
	filtered_table_df.columns = ['gs-' + col for col in filtered_table_df.columns]
	filtered_table_df[['gs-fasta_column', 'gs-submission_id']].to_csv(f'{outdir}/fasta_filepaths.csv', index=False, header=False)

	return filtered_table_df, missing_mandatory, mandatory_list

def filter_table_by_shared(table: pd.DataFrame, static_metadata: pd.DataFrame, repository_column_map: pd.DataFrame, entity_id: str) -> Tuple [pd.DataFrame, list, list]:
	table = table.copy()

	mandatory_list = [entity_id,'sequence_name','authors','collection_date']
	optional_list = ['organism', 'bioproject']
	all_attributes = mandatory_list + optional_list

	for index, row in static_metadata[static_metadata['db'].isin(['gen'])].iterrows():
		table[row['key']] = row['value']

	rename_dict = repository_column_map.set_index('terra')['gen'].dropna().to_dict()
	table.rename(columns=rename_dict, inplace = True)

	missing_mandatory = list(set(mandatory_list) - set(table.columns))

	if missing_mandatory:
		print("Your Terra table is missing the following required attributes for seqsender submission: " + str(missing_mandatory))

	filtered_table_df = table[[col for col in table.columns if col in all_attributes]]
	remove_nas(entity_id, filtered_table_df, mandatory_list)
	return filtered_table_df, missing_mandatory, mandatory_list

def main(tablename: str, biosample_schema: str, static_metadata_file: str, repository_column_map_file: str, entity_id: str, db_selection: str, outdir: str, cloud_uri: Optional[str] = None) -> None:
	db_selection = db_selection.split(',')
	table = pd.read_csv(tablename, delimiter='\t', header=0, dtype=str)
	# table = pd.read_csv(tablename, delimiter='\t', header=0, dtype={entity_id: 'str'})
	# change the split back here when using in terra
	# table = table[table[entity_id].isin("~{sep=',' sample_names}".split(","))]
	table = table[table[entity_id].isin("~{sep='*' sample_names}".split("*"))]
	print(table)
	static_metadata = pd.read_csv(static_metadata_file, delimiter=',', header=0)
	repository_column_map = pd.read_csv(repository_column_map_file, delimiter=',', header=0)


	if 'bs' in db_selection:
		biosample_filtered_table, missing_biosample, mandatory_biosample_list = filter_table_by_biosample(table, biosample_schema, static_metadata, repository_column_map, entity_id)
		print(f"Missing Biosample fields: {missing_biosample}")
		biosample_filtered_table.to_csv(f'{outdir}/biosample_table.csv', header = True, index = False, sep = ",")
	if 'sra' in db_selection:
		sra_filtered_table, missing_sra, mandatory_sra_list = filter_table_by_sra(table, static_metadata, repository_column_map, entity_id, outdir, cloud_uri)
		print(f"Missing SRA fields: {missing_sra}")
		sra_filtered_table.to_csv(f'{outdir}/sra_table.csv', header = True, index = False, sep = ",")
	if 'gs' in db_selection:
		gisaid_filtered_table, missing_gisaid, mandatory_gisaid_list = filter_table_by_gisaid_cov(table, static_metadata, repository_column_map, entity_id, outdir)
		print(f"Missing GISAID fields: {missing_gisaid}")
		gisaid_filtered_table.to_csv(f'{outdir}/gisaid_table.csv', header = True, index = False, sep = ",")
	shared_filtered_table, missing_shared, mandatory_shared_list = filter_table_by_shared(table, static_metadata, repository_column_map, entity_id)
	print(f"Missing Shared fields: {missing_shared}")
	shared_filtered_table.to_csv(f'{outdir}/shared_table.csv', header = True, index = False, sep = ",")


	if 'gs' in db_selection and 'bs' not in db_selection and 'sra' not in db_selection:
		merged_metadata_tables = pd.merge(shared_filtered_table, gisaid_filtered_table, left_on=entity_id, right_on = f'gs-{entity_id}', how='outer')
	elif 'bs' in db_selection and 'gs' not in db_selection and 'sra' not in db_selection:
		merged_metadata_tables = pd.merge(shared_filtered_table, biosample_filtered_table, left_on=entity_id, right_on = f'gs-{entity_id}', how='outer')
	elif 'sra' in db_selection and 'gs' not in db_selection and 'bs' not in db_selection:
		merged_metadata_tables = pd.merge(shared_filtered_table, sra_filtered_table, left_on=entity_id, right_on = f'gs-{entity_id}', how='outer')
	elif 'gs' not in db_selection and 'bs' in db_selection and 'sra' in db_selection:
		merged_metadata_tables1 = pd.merge(shared_filtered_table, biosample_filtered_table, left_on=entity_id, right_on = f'bs-{entity_id}', how='outer')
		merged_metadata_tables = pd.merge(merged_metadata_tables1, sra_filtered_table, left_on=entity_id, right_on = f'sra-{entity_id}', how='outer')
	elif 'gs' in db_selection and 'bs' in db_selection and 'sra' in db_selection:
		merged_metadata_tables1 = pd.merge(shared_filtered_table, biosample_filtered_table, left_on=entity_id, right_on = f'bs-{entity_id}', how='outer')
		merged_metadata_tables2 = pd.merge(merged_metadata_tables1, sra_filtered_table, left_on=entity_id, right_on = f'sra-{entity_id}', how='outer')
		merged_metadata_tables = pd.merge(merged_metadata_tables2, gisaid_filtered_table, left_on=entity_id, right_on = f'gs-{entity_id}', how='outer')
	else:
		print('Something seems to be wrong here')


	columns_to_remove = [f'gs-{entity_id}', f'bs-{entity_id}', entity_id, f'sra-{entity_id}', 'gs-fasta_column', 'gs-submission_id']
	columns_to_remove = [col for col in columns_to_remove if col in merged_metadata_tables.columns]
	merged_metadata_tables.drop(columns=columns_to_remove, inplace=True)

	merged_metadata_tables.to_csv(f'{outdir}/merged_metadata.csv', header = True, index = False, sep = ",")


		
if __name__ == '__main__':
	main(

		tablename="~{table_name}-data.tsv",
		biosample_schema="${biosample_schema_file}",
		static_metadata_file="~{static_metadata_csv}",
		repository_column_map_file="~{repository_column_map_csv}",
		entity_id="~{table_name}_id",
		outdir = "${current_dir}",
		db_selection ="~{repository_selection}",
		cloud_uri =" ~{sra_transfer_gcp_bucket}"
	)