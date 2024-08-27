version 1.0
workflow seqsender {
	input {
		String mode
		# submit - submit to selected repositories
		# status - retrieve submission status
		Boolean submit_to_biosample
		Boolean submit_to_sra
		Boolean submit_to_gisaid
		String organism
		String submission_dir = "/data"
		String submission_name = "public_health"
		File config_yaml
		File metadata_file
		Boolean have_fasta
		File? concatenated_fasta
		Boolean test = true
		File? submission_tgz
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

	output {
		File? submission_log = seqsender_submit.submission_log
		File? submission_results = seqsender_submit.submission_results
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
	File metadata_file
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
		chmod +x ~{gisaid_cov_cli}
		mv ~{gisaid_cov_cli} /seqsender/gisaid_cli/

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
		~{true='--test' false='' test}

		cd "~{submission_dir}"
		tar -cvzf "~{submission_name}_results.tar.gz" "~{submission_name}/submission_files"
		ls

	>>>

	output {
		File? submission_log = "submission_log.csv"
		File? submission_results = "~{submission_name}_results.tar.gz"
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