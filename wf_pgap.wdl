version 1.0

workflow ncbi_pgap {
    input {
        String sample_id
        File assembly_fasta
        String supplemental_data
        String taxon
        Boolean ignore_errors
        Int cpu
        Int memory
    }

    call pgap_annotate {
        input:
            sample_id = sample_id
            assembly_fasta = assembly_fasta,
            supplemental_data = supplemental_data,
            taxon=taxon,
            ignore_errors = ignore_errors,
            cpu = cpu,
            memory = memory
    }

    output {
        File? pgap_ani_tax_report = pgap_annotate.pgap_ani_tax_report
        File? pgap_ani_tax_report_xml = pgap_annotate.pgap_ani_tax_report_xml
        File? pgap_annotated_proteins_fasta = pgap_annotate.pgap_annotated_proteins_fasta
        File? pgap_genomic_fasta = pgap_annotate.pgap_genomic_fasta
        File? pgap_gbk_annotation = pgap_annotate.pgap_gbk_annotation
        File? pgap_gff3_annotation = pgap_annotate.pgap_gff3_annotation
        File? pgap_annotated_sequence = pgap_annotate.pgap_annotated_sequence
        File? pgap_annotated_cds = pgap_annotate.pgap_annotated_cds
        File? pgap_translated_cds = pgap_annotate.pgap_translated_cds
        File? pgap_gff_with_sequence = pgap_annotate.pgap_gff_with_sequence
        File? pgap_foreign_sequence = pgap_annotate.pgap_foreign_sequence
        File? pgap_completeness_contamination = pgap_annotate.pgap_completeness_contamination
        File? pgap_log = pgap_annotate.pgap_log
    }
}

task pgap_annotate {
    input {
        String sample_id
        File assembly_fasta
        String supplemental_data
        String taxon
        Boolean ignore_errors
        Int cpu
        Int memory
    }

    command <<<
        PYTHON3 <<CODE

        import yaml

        submol = {
            'organism': {
                'genus_species': '~{taxon}'
            }
        }
        with open('submol.yaml', 'w') as file:
            yaml.dump(submol, file, sort_keys=False, default_flow_style=False)

        

        controller = {
            'fasta': {
                'class': 'File',
                'location': '~{assembly_fasta}'
            },
            'submol': {
                'class': 'File',
                'location': 'submol.yaml'
            },
            'supplemental_data': {
                'class': 'Directory',
                'location': '~{supplemental_data}'
            },
            'report_usage': 'False',
            'ignore_all_errors': '~{ignore_errors}'
        }
        with open('controller.yaml', 'w') as file:
            yaml.dump(controller, file, sort_keys=False, default_flow_style=False)
        
        CODE

    cwltool --'~{cpu}' --'~{memory}' --timestamps --debug --disable-color --preserve-entire-environment /pgap/pgap/pgap.cwl controller.yaml

    >>>

    output {
        File? pgap_ani_tax_report = "~{sample_id}_ani-tax-report.txt"
        File? pgap_ani_tax_report_xml = "~{sample_id}_ani-tax-report.xml"
        File? pgap_annotated_proteins_fasta = "~{sample_id}_annot.faa"
        File? pgap_genomic_fasta = "~{sample_id}_annot.fna"
        File? pgap_gbk_annotation = "~{sample_id}_annot.gbk"
        File? pgap_gff3_annotation = "~{sample_id}_annot.gff"
        File? pgap_annotated_sequence = "~{sample_id}_annot.sqn"
        File? pgap_annotated_cds = "~{sample_id}_annot_cds_from_genomic.fna"
        File? pgap_translated_cds = "~{sample_id}_annot_translated_cds.faa"
        File? pgap_gff_with_sequence = "~{sample_id}_annot_with_genomic_fasta.gff"
        File? pgap_foreign_sequence = "~{sample_id}_calls.tab"
        File? pgap_completeness_contamination = "~{sample_id}_checkm.txt"
        File? pgap_log = "~{sample_id}_cwltool.log"
    } 

    runtime {
        docker: "library/ubuntu:jammy"
        memory:"~{memory}"
        cpu: "~{cpu}"
        disks: "local-disk 100 SSD"
        preemptible:  1
  }
}