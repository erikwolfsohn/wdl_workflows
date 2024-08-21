version 1.0

workflow seqsender_submission_prep {
	String project_name
	String workspace_name
	String table_name
	Array[String] sample_names
	Array[String] db_selection
	String biosample_schema
	String sra_transfer_gcp_bucket
	String? fasta_column
	String? submission_column
	File repository_column_map_csv
	File static_metadata_csv
	File? input_table
	Int disk_size = 100

	call prepare_seqsender_submission {
		input:
		project_name = project_name,
		workspace_name = workspace_name,
		table_name = table_name,
		sample_names = sample_names,
		db_selection = db_selection,
		biosample_schema = biosample_schema,
		sra_transfer_gcp_bucket = sra_transfer_gcp_bucket,
		repository_column_map_csv = repository_column_map_csv,
		static_metadata_csv = static_metadata_csv,
		input_table = input_table,
		disk_size = disk_size
	}

	if (defined(sra_transfer_gcp_bucket)) {
		call upload_sra {
			input:
			sra_filepaths = prepare_seqsender_submission.sra_filepaths,
			sra_transfer_gcp_bucket = sra_transfer_gcp_bucket
		}
	}

	if (defined(fasta_column)) {
		call merge_fasta {
			input:
			fasta_column = fasta_column,
			submission_column = submission_column,
			table_name = table_name
		}
	}

	output {
		File seqsender_metadata = prepare_seqsender_submission.seqsender_metadata
		File sra_filepaths = prepare_seqsender_submission.sra_filepaths
		File stdout = prepare_seqsender_submission.stdout
		File stderr = prepare_seqsender_submission.stderr
	}

}

task prepare_seqsender_submission {
	input {
		String project_name
		String workspace_name
		String table_name
		Array[String] sample_names
		Array[String] db_selection
		String biosample_schema
		String sra_transfer_gcp_bucket
		File repository_column_map_csv
		File static_metadata_csv
		File? input_table
		Int memory = 8
		Int cpu = 4
		String docker = "ewolfsohn/seqsender:v1.2.0_terratools"
		Int disk_size = 100		
	}
	meta {
		# added so that call caching is always turned off
		volatile: true
	}
	command <<<
		#python export_large_tsv.py --project "~{project_name}" --workspace "~{workspace_name}" --entity_type ~{table_name} --tsv_filename ~{table_name}-data.tsv

		# when running locally, use the input_table in place of downloading from Terra
		current_dir=$(pwd)
		cp ~{input_table} ~{table_name}-data.tsv
		biosample_schema_file=$(find /seqsender/config/biosample/ -type f -name "~{biosample_schema}")

		python /seqsender/process_terra_table.py ~{table_name}-data.tsv "$biosample_schema_file" ~{static_metadata_csv} ~{repository_column_map_csv}  "entity:~{table_name}_id" "$current_dir" --db_selection bs sra gs --cloud_uri gs://theiagen_sra_transfer/

	>>>

	output {
		File seqsender_metadata = "merged_metadata.csv"
		File sra_filepaths = "filepaths.csv"
		File stdout = stdout()
		File stderr = stderr()
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
		File sra_filepaths
		String sra_transfer_gcp_bucket
		Int memory = 8
		Int cpu = 4
		String docker = "ewolfsohn/seqsender:v1.2.0_terratools"
		Int disk_size = 100
	}
	
	command <<<

		while IFS= read -r line; do
			echo "running gsutil to transfer sra files to ~{sra_transfer_gcp_bucket}"
			echo "running \`gsutil -m cp ${line} ~{sra_transfer_gcp_bucket}\`"
			gsutil -m cp -n "$line" "${sra_transfer_gcp_bucket}"
		done < ~{sra_filepaths}

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
		String? fasta_column
		String? submission_column
		String table_name
		Int memory = 8
		Int cpu = 4
		String docker = "ewolfsohn/seqsender:v1.2.0_terratools"
		Int disk_size = 100
	}

	command <<<
		python <<CODE
		import pandas as pd
		from Bio import SeqIO

		table = pd.read_csv('~{table_name}-data.tsv', delimiter='\t', header=0)
		#table = table.drop(table.columns[0], axis=1)

		def process_fasta_files(table, fasta_column, submission_id_column, output_file):
			with open(output_file, 'w') as outfile:
				for index, row in table.iterrows():
					with open(row[fasta_column], 'r') as fasta_file:
						for record in SeqIO.parse(fasta_file, "fasta"):
							record.id = row[submission_id_column]
							record.description = ""  
							SeqIO.write(record, outfile, "fasta")
		
		process_fasta_files(table, "~{fasta_column}", "~{submission_column}", 'concatenated_fastas.fasta')

		CODE
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