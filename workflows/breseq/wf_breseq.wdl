version 1.0
workflow breseq_workflow {
  input {
    String sample_id
    File reference
    File read1
    File? read2
    Boolean draft_reference_sequence = true
    # true = -c
    # false = -r
    # default true
    Boolean nanopore_reads = false
    # true = -x
    # false = ""
    # default false
    Boolean polymorphic_mode = false
    # true = -p
    # false = ""
    # default false
    Int memory = 16
    Int cpu = 4
    String docker_image = "quay.io/biocontainers/breseq:0.38.3--h43eeafb_0"
    Int disk_size = 100
  }

  call breseq_task {
    input:
      sample_id = sample_id,
      reference = reference,
      read1 = read1,
      read2 = read2,
      draft_reference_sequence = draft_reference_sequence,
      nanopore_reads = nanopore_reads,
      polymorphic_mode = polymorphic_mode,
      memory = memory,
      cpu = cpu,
      docker_image = docker_image,
      disk_size = disk_size
  }

  output {
        File? breseq_summary = breseq_task.breseq_summary
        File? breseq_marginal_predictions = breseq_task.breseq_marginal_predictions
        File? breseq_mutation_predictions = breseq_task.breseq_mutation_predictions
        File? breseq_log = breseq_task.breseq_log
        File? breseq_gdtools_output = breseq_task.breseq_gdtools_output
        File? breseq_output_archive = breseq_task.breseq_output_archive
    }
}

task breseq_task {
  input {
    String sample_id
    File reference
    File read1
    File? read2
    Boolean draft_reference_sequence
    # true = -c
    # false = -r
    # default true
    Boolean nanopore_reads
    # true = -x
    # false = ""
    # default false
    Boolean polymorphic_mode
    # true = -p
    # false = ""
    # default false
    Int memory
    Int cpu
    String docker_image
    Int disk_size
  }

  command <<<

  # date and version control
  date | tee DATE
  breseq -v | tee VERSION

  # run breseq on input gbk or gff
  breseq \
  ~{'-j ' + cpu} \
  ~{true='-p' false='' polymorphic_mode} \
  ~{true='-c ' false='-r ' draft_reference_sequence} ~{reference} \
  ~{true='-x' false='' nanopore_reads} \
  ~{read1} ~{read2}

  tar -cvzf ~{sample_id}_predictions.tar.gz \
  output/summary.html \
  output/marginal.html \
  output/index.html \
  output/log.txt \
  output/output.gd
  >>>

  output {
    File? breseq_summary = "output/summary.html"
    File? breseq_marginal_predictions = "output/marginal.html"
    File? breseq_mutation_predictions = "output/index.html"
    File? breseq_log = "output/log.txt"
    File? breseq_gdtools_output = "output/output.gd"
    File? breseq_output_archive = "~{sample_id}_predictions.tar.gz"
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