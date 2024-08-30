version 1.0
workflow seqsender {
	input {
		String mode
		# submit - submit to selected repositories
		# status - retrieve submission status
		Boolean submit_to_biosample = false
		Boolean submit_to_sra = false
		Boolean submit_to_gisaid = false
		String organism = "COV"
		String submission_dir = "/data"
		String submission_name = "public_health"
		File config_yaml
		File? metadata_file
		Boolean have_fasta = false
		File? concatenated_fasta
		Boolean test = true
		File? submission_tgz
		File? submission_log
		File? gisaid_cov_cli
		Int memory = 8
		Int cpu = 4
		String docker_image = "ewolfsohn/seqsender:v1.2.0_terratools"
		Int disk_size = 100	
	}

	if (mode == "submit") {
		call seqsender_submit{
			input:
				submit_to_biosample = submit_to_biosample,
				submit_to_sra = submit_to_sra,
				submit_to_gisaid = submit_to_gisaid,
				organism = organism,
				submission_dir = submission_dir,
				submission_name = submission_name,
				config_yaml = config_yaml,
				metadata_file = metadata_file,
				have_fasta = have_fasta,
				concatenated_fasta = concatenated_fasta,
				test = test,
				gisaid_cov_cli = gisaid_cov_cli,
				memory = memory,
				cpu = cpu,
				docker_image = docker_image,
				disk_size = disk_size
		}
	}

	if (mode == "status") {
		call seqsender_status{
			input:
				submission_dir = submission_dir,
				submission_name = submission_name,
				submission_tgz = submission_tgz,
				submission_log = submission_log,
				config_yaml = config_yaml,
				gisaid_cov_cli = gisaid_cov_cli
		}
	}

	output {
		File? seqsender_submit_log = seqsender_submit.submission_log
		File? seqsender_submit_results = seqsender_submit.submission_results
		File? seqsender_submit_summary = seqsender_submit.submission_summary
		File? seqsender_status_log = seqsender_status.status_log
		File? seqsender_status_results = seqsender_status.status_results
		File? seqsender_status_summary = seqsender_status.status_summary
	}

}

task seqsender_status {
  input {
	String submission_dir
	String submission_name
	File config_yaml
	File? submission_tgz
	File? submission_log
	File? gisaid_cov_cli
	Int memory = 8
	Int cpu = 2
	String docker_image = "ewolfsohn/seqsender:v1.2.0_terratools"
	Int disk_size = 20
	}

	command <<<
		~{true='chmod +x ' false='' submit_to_gisaid} ~{gisaid_cov_cli}
		~{true='mv ' false='' submit_to_gisaid} ~{gisaid_cov_cli} ~{true=' /seqsender/gisaid_cli/' false='' submit_to_gisaid}

		tar -zxvf "~{submission_tgz}"
		mv "~{config_yaml}" "data/~{submission_name}_config.yaml"

		python3 <<CODE
		
		import pandas as pd

		df = pd.read_csv("~{submission_log}")
		df['Config_File'] = "data/~{submission_name}_config.yaml"
		df['Submission_Directory'] = "data/~{submission_name}/submission_files/"

		df.to_csv("data/submission_log.csv", index=False)

		CODE

		python /seqsender/seqsender.py \
		submission_status \
		--submission_dir "data" \
		--submission_name "~{submission_name}" > "~{submission_name}_status_summary.txt"

		tar -cvzf "~{submission_name}_results.tar.gz" "data/~{submission_name}/submission_files"
		cp "data/submission_log.csv"  "~{submission_name}_submission_log.csv"
	>>>

	output {
		File? status_log = "~{submission_name}_submission_log.csv"
		File? status_results = "~{submission_name}_results.tar.gz"
		File? status_summary = "~{submission_name}_status_summary.txt"
		}

	runtime {
		docker: "~{docker_image}"
		memory: "~{memory} GB"
		cpu: cpu
		disks: "local-disk " + disk_size + " SSD"
		disk: disk_size + " GB"
		maxRetries: 3
		preemptible: 0
		}
}

task seqsender_submit {
  input {
	Boolean submit_to_biosample
	# true --biosample
	# false ''
	Boolean submit_to_sra
	# true --sra
	# false ''
	Boolean submit_to_gisaid
	# true --gisaid
	# false ''
	String organism
	String submission_dir
	String submission_name
	File config_yaml
	File? metadata_file
	Boolean have_fasta
	File? concatenated_fasta
	Boolean test
	# true --test
	# false starts a prod submission
	# default true
	File? gisaid_cov_cli
	Int memory
	Int cpu
	String docker_image
	Int disk_size
	}

	command <<<
		~{true='chmod +x ' false='' submit_to_gisaid} ~{gisaid_cov_cli}
		~{true='mv ' false='' submit_to_gisaid} ~{gisaid_cov_cli} ~{true=' /seqsender/gisaid_cli/' false='' submit_to_gisaid}

		python /seqsender/seqsender.py \
		submit \
		~{true='--biosample' false='' submit_to_biosample} \
		~{true='--sra' false='' submit_to_sra} \
		~{true='--gisaid' false='' submit_to_gisaid} \
		--organism "~{organism}" \
		--submission_dir "~{submission_dir}" \
		--submission_name "~{submission_name}" \
		--config_file ~{config_yaml} \
		--metadata_file ~{metadata_file} \
		~{true='--fasta_file' false='' have_fasta} ~{concatenated_fasta} \
		~{true='--test' false='' test} > "~{submission_name}_submission_summary.txt"

		tar -cvzf "~{submission_name}_results.tar.gz" "~{submission_dir}/~{submission_name}/submission_files"
		cp "~{submission_dir}/submission_log.csv"  "~{submission_name}_submission_log.csv"
	>>>

	output {
		File? submission_log = "~{submission_name}_submission_log.csv"
		File? submission_results = "~{submission_name}_results.tar.gz"
		File? submission_summary = "~{submission_name}_submission_summary.txt"
		}

	runtime {
		docker: "~{docker_image}"
		memory: "~{memory} GB"
		cpu: cpu
		disks: "local-disk " + disk_size + " SSD"
		disk: disk_size + " GB"
		maxRetries: 3
		preemptible: 0
		}
}