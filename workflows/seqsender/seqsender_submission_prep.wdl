version 1.0
# workflow to process terra table for seqsender submission
# huge thanks to dakota howard et al. @ cdc for developing seqsender & theiagen genomics for their various terra submission workflows which I frankensteined into here
workflow seqsender_submission_prep {
	input {
		String project_name
		String workspace_name
		String table_name
		Array[String] sample_names
		String repository_selection
		String biosample_schema_name
		String? sra_transfer_gcp_bucket
		String? fasta_column
		File repository_column_map_csv
		File static_metadata_csv
		File? input_table
		Boolean check_coverage = false
		Boolean check_contigs = false
		Boolean check_seq_length = false
		String coverage_column = 'placeholder'
		String contigs_column = 'placeholder'
		String seq_length_column = 'placeholder'
		Int threshold_min_coverage = 85
		Int threshold_max_seq_length = 1000000
		Int threshold_max_contigs = 200
	}

	call prepare_seqsender_submission {
		input:
			project_name = project_name,
			workspace_name = workspace_name,
			table_name = table_name,
			sample_names = sample_names,
			repository_selection = repository_selection,
			biosample_schema_name = biosample_schema_name,
			sra_transfer_gcp_bucket = sra_transfer_gcp_bucket,
			repository_column_map_csv = repository_column_map_csv,
			static_metadata_csv = static_metadata_csv,
			input_table = input_table,
			threshold_min_coverage = threshold_min_coverage,
			threshold_max_seq_length = threshold_max_seq_length,
			threshold_max_contigs = threshold_max_contigs,
			coverage_column = coverage_column,
			contigs_column = contigs_column,
			seq_length_column = seq_length_column,
			check_coverage = check_coverage,
			check_contigs = check_contigs,
			check_seq_length = check_seq_length
	}

	if (defined(sra_transfer_gcp_bucket)) {
		call upload_sra {
			input:
				seqsender_sra_filepaths = prepare_seqsender_submission.seqsender_sra_filepaths,
				sra_transfer_gcp_bucket = sra_transfer_gcp_bucket
		}
	}

	if (defined(fasta_column)) {
		call merge_fasta {
			input:
				seqsender_fasta_filepaths = prepare_seqsender_submission.seqsender_fasta_filepaths
		}
	}

	output {
		File seqsender_metadata = prepare_seqsender_submission.seqsender_metadata
		File? seqsender_sra_filepaths = prepare_seqsender_submission.seqsender_sra_filepaths
		File? seqsender_fasta_filepaths = prepare_seqsender_submission.seqsender_fasta_filepaths
		File? seqsender_concatenated_fasta = merge_fasta.seqsender_concatenated_fasta
	}

}

task prepare_seqsender_submission {
	input {
		String project_name
		String workspace_name
		String table_name
		Array[String] sample_names
		String repository_selection
		String biosample_schema_name
		String? sra_transfer_gcp_bucket
		File repository_column_map_csv
		File static_metadata_csv
		File? input_table
		Int memory = 8
		Int cpu = 4
		String docker = "ewolfsohn/seqsender:v1.2.0_terratools"
		Int disk_size = 100
		Boolean check_coverage
		Boolean check_contigs
		Boolean check_seq_length
		String? coverage_column
		String? contigs_column
		String? seq_length_column
		Int? threshold_min_coverage
		Int? threshold_max_seq_length
		Int? threshold_max_contigs		
	}

	meta {
		volatile: true
	}
	command <<<

		current_dir=$(pwd)
		# change this back when using in terra
		python /seqsender/export_large_tsv.py --project "~{project_name}" --workspace "~{workspace_name}" --entity_type ~{table_name} --tsv_filename ~{table_name}-data.tsv
		# cp ~{input_table} ~{table_name}-data.tsv
		biosample_schema_file=$(find /seqsender/config/biosample/ -type f -name "~{biosample_schema_name}")

		python3 <<CODE

		import xml.etree.ElementTree as ET
		from typing import Optional, Tuple
		import numpy as np
		import pandas as pd
		from datetime import datetime
		import json


		def remove_nas(entity_id, table, required_metadata):
			table.replace(r'^\s+$', np.nan, regex=True) 
			excluded_samples = table[table[required_metadata].isna().any(axis=1)] 
			excluded_samples.set_index(entity_id.lower(), inplace=True) 
			excluded_samples = excluded_samples[excluded_samples.columns.intersection(required_metadata)] 
			excluded_samples = excluded_samples.loc[:, excluded_samples.isna().any()] 
			table.dropna(subset=required_metadata, axis=0, how='any', inplace=True) 

			return table, excluded_samples


		def format_location(row):
			return f"{row['continent']}/{row['country']}/{row['state']}/{row['county']}"

		def format_gisaid_virus_name(row):
			try:
				year = datetime.strptime(row['collection_date'], '%Y-%m-%d').year
			except ValueError:
				year = None
				
			return f"{row['virus_prefix']}/{row['country']}/{row['submission_id']}/{year}"


		def format_biosample_isolate_name(row):
			try:
				year = datetime.strptime(row['collection_date'], '%Y-%m-%d').year
			except ValueError:
				year = None
				
			return f"{row['isolate_prefix']}/{row['country']}/{row['sample_name']}/{year}"


		def filter_table_by_biosample(table, biosample_schema, static_metadata, repository_column_map, entity_id) -> Tuple [pd.DataFrame, list, list]:
			
			table = table.copy()
			table['entity_id_copy'] = table[entity_id]
			
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
			if 'description' not in optional_list:
				optional_list.append('description')

			try:
				mandatory_list.remove('collection_date')
			except ValueError:
				print('Specimen is missing a collection date. It will probably fail submission.')


			all_attributes = mandatory_list + optional_list

			for index, row in static_metadata[static_metadata['db'].isin(['bs'])].iterrows():
				table[row['key']] = row['value']

			rename_dict = repository_column_map.set_index('terra')['biosample'].dropna().to_dict()
			table.rename(columns=rename_dict,inplace = True)

			# handle errors here caused by missing collection dates
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

		def filter_table_by_sra(table, static_metadata, repository_column_map, entity_id, outdir, cloud_uri = None) -> Tuple [pd.DataFrame, list, list]:
			table = table.copy()

			mandatory_list = [entity_id, "sample_name", "library_name", "library_strategy", "library_source", "library_selection", "library_layout", "platform", "instrument_model", "design_description", "file_1", "platform","file_location"]
			optional_list = ["file_2","file_3","file_4","assembly","fasta_file", "biosample_accession", "title"]
			

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

		def filter_table_by_gisaid_cov(table, static_metadata, repository_column_map, entity_id, outdir) -> Tuple [pd.DataFrame, list, list]:
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

		def filter_table_by_shared(table, static_metadata, repository_column_map, entity_id) -> Tuple [pd.DataFrame, list, list]:
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
		
		
		def check_coverage(table) -> pd.DataFrame:
			table['~{coverage_column}'] = pd.to_numeric(table['~{coverage_column}'], errors='coerce')
			table['~{coverage_column}'] = table['~{coverage_column}'].round().astype(int)
			if table['~{coverage_column}'].isnull().any():
				print("Some rows were removed due to non-numeric values.")
			
			table = table[table['~{coverage_column}'] >= ~{threshold_min_coverage}]

			table['~{coverage_column}'] = table['~{coverage_column}'].astype(str)

			return table



		def check_contigs(table) -> pd.DataFrame:
			table['~{contigs_column}'] = pd.to_numeric(table['~{contigs_column}'], errors='coerce')
			table['~{contigs_column}'] = table['~{contigs_column}'].round().astype(int)
			if table['~{contigs_column}'].isnull().any():
				print("Some rows were removed due to non-numeric values.")
			
			table = table[table['~{contigs_column}'] >= ~{threshold_max_contigs}]

			table['~{contigs_column}'] = table['~{contigs_column}'].astype(str)

			return table

		def check_seq_length(table) -> pd.DataFrame:
			table['~{seq_length_column}'] = pd.to_numeric(table['~{seq_length_column}'], errors='coerce')
			table['~{seq_length_column}'] = table['~{seq_length_column}'].round().astype(int)
			if table['~{seq_length_column}'].isnull().any():
				print("Some rows were removed due to non-numeric values.")
			
			table = table[table['~{seq_length_column}'] >= ~{threshold_max_seq_length}]

			table['~{seq_length_column}'] = table['~{seq_length_column}'].astype(str)

			return table


		def main(tablename, biosample_schema, static_metadata_file, repository_column_map_file, entity_id, db_selection, outdir, cloud_uri = None):
			db_selection = db_selection.split(',')
			table = pd.read_csv(tablename, delimiter='\t', header=0, dtype=str)
			# table = pd.read_csv(tablename, delimiter='\t', header=0, dtype={entity_id: 'str'})
			# change the split back here when using in terra
			# table = table[table[entity_id].isin("~{sep=',' sample_names}".split(","))]
			table = table[table[entity_id].isin("~{sep='*' sample_names}".split("*"))]
			~{true='table = check_coverage(table)' false='' check_coverage}
			~{true='table = check_contigs(table)' false='' check_contigs}
			~{true='table = check_seq_length(table)' false='' check_seq_length}
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

		CODE

	>>>

	output {
		File seqsender_metadata = "merged_metadata.csv"
		File? seqsender_sra_filepaths = "filepaths.csv"
		File? seqsender_fasta_filepaths = "fasta_filepaths.csv"
	}

	runtime {
		docker: docker
		memory: memory + " GB"
		cpu: cpu
		disks:  "local-disk " + disk_size + " SSD"
		disk: disk_size + " GB"
		preemptible: 0
	}

}

task upload_sra {
	input {
		File? seqsender_sra_filepaths
		String? sra_transfer_gcp_bucket
		Int memory = 8
		Int cpu = 4
		String docker = "ewolfsohn/seqsender:v1.2.0_terratools"
		Int disk_size = 100
	}
	
	command <<<

		while IFS= read -r line; do
			echo "running \`gsutil -m cp -n ${line} ~{sra_transfer_gcp_bucket}\`"
			gsutil -m cp -n "${line}" "~{sra_transfer_gcp_bucket}"
		done < ~{seqsender_sra_filepaths}

	>>>

	runtime {
		docker: docker
		memory: memory + " GB"
		cpu: cpu
		disks:  "local-disk " + disk_size + " SSD"
		disk: disk_size + " GB"
		preemptible: 0
	}

}

task merge_fasta {
	input {
		File? seqsender_fasta_filepaths
		Int memory = 8
		Int cpu = 4
		String docker = "ewolfsohn/seqsender:v1.2.0_terratools"
		Int disk_size = 100
	}

	command <<<

		python <<CODE

		import pandas as pd
		from Bio import SeqIO
		import os
		import subprocess
		import sys
		
		table = pd.read_csv("~{seqsender_fasta_filepaths}", header=None, names=['fasta_path', 'fasta_header_names'])

		for index, row in table.iterrows():
			fasta_path = row['fasta_path']
			new_header = row['fasta_header_names']

			command = ['gsutil', '-m', 'cp', '-n', fasta_path, '.']
			result = subprocess.run(command, text=True, capture_output=True)
			if result.returncode != 0:
				print("Command failed with return code:", result.returncode)
				print("Error output:", result.stderr)
				sys.exit(result.returncode)
			else:
				print("Command executed successfully:", result.stdout)

			table.at[index, 'basenames'] = os.path.basename(fasta_path)
			print(table)

		all_records = []
		for index, row in table.iterrows():
			fasta_file = row['basenames']
			new_header = row['fasta_header_names']
			records = list(SeqIO.parse(fasta_file, 'fasta'))
			records[0].id = new_header
			records[0].description = ''
			all_records.extend(records)
		merged_fasta_path = 'seqsender_concatenated_fasta.fasta'
		SeqIO.write(all_records, merged_fasta_path, 'fasta')

		CODE

	>>>

	output {
		File seqsender_concatenated_fasta = 'seqsender_concatenated_fasta.fasta'
	}

	runtime {
		docker: docker
		memory: memory + " GB"
		cpu: cpu
		disks:  "local-disk " + disk_size + " SSD"
		disk: disk_size + " GB"
		preemptible: 0
	}

}