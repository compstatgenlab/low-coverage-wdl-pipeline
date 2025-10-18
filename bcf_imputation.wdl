version 1.0

# Workflow for imputation of a single chromosome
# Scattering over chunks
# Using a bcf reference panel

#### Workflow part ####
workflow impute {
  input {
    File bam_list
    File chunk_file
    String ref_panel
    File map
    String output_prefix
    String chr
    Int imputation_threads = 1
    Int imputation_ram = 4
    Int imputation_storage = 50
    Int ligation_threads = 1
    Int ligation_ram = 4
    Int ligation_storage = 50
  }

  scatter (idx in range(length(read_lines(chunk_file)))) {
    call ImputeChunk {
      input:
        bam_list = bam_list,
        chunk_file = chunk_file,
        ref_panel = ref_panel,
        map = map,
        output_prefix = output_prefix,
        idx = idx,
        chr = chr,
        imputation_threads = imputation_threads,
        imputation_ram = imputation_ram,
        imputation_storage = imputation_storage
    }
  }

  call Ligate {
    input:
      imputed_chunks = ImputeChunk.imputed_chunk,
      imputed_chunk_indexs = ImputeChunk.imputed_chunk_index,
      output_prefix = output_prefix,
      chr = chr,
      ligation_threads = ligation_threads,
      ligation_ram = ligation_ram,
      ligation_storage = ligation_storage
  }

  output {
    File imputed_bcf = Ligate.imputed_bcf
    File imputed_index = Ligate.imputed_index
    Array[File] impute_log_output = ImputeChunk.impute_log
    File ligate_log_output = Ligate.ligate_log
    Array[File] impute_time_output = ImputeChunk.impute_time
    File ligate_time_output = Ligate.ligate_time
  }
}




#### Task part ####
task ImputeChunk {
  input {
    File bam_list
    File chunk_file
    String ref_panel
    File map
    String output_prefix
    Int idx
    String chr
    Int imputation_threads = 1
    Int imputation_ram = 4
    Int imputation_storage = 50
  }

  command <<<
    set -euo pipefail
    
    export GCS_OAUTH_TOKEN=$(curl -s -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | jq -r ".access_token")

    # Imputation (and phasing) chunk by chunk
    LINE=$(sed -n "$((~{idx}+1))p" ~{chunk_file})

    printf -v ID "%02d" $(echo $LINE | cut -d" " -f1)
    IRG=$(echo $LINE | cut -d" " -f3)
    ORG=$(echo $LINE | cut -d" " -f4)
    REGS=$(echo ${IRG} | cut -d":" -f 2 | cut -d"-" -f1)
    REGE=$(echo ${IRG} | cut -d":" -f 2 | cut -d"-" -f2)
    
    OUT=~{output_prefix}_chr~{chr}_~{idx}.bcf

    # Run imputation for the chunk
    /usr/bin/time -vo impute_chr~{chr}_~{idx}.time \
    GLIMPSE2_phase --bam-list ~{bam_list} --reference ~{ref_panel} --output ${OUT} --log ~{output_prefix}_chr~{chr}_~{idx}.log --thread ~{imputation_threads} --map ~{map} --input-region ${IRG} --output-region ${ORG}
  >>>

  output {
    File imputed_chunk = output_prefix + "_chr" + chr + "_" + idx + ".bcf"
    File imputed_chunk_index = output_prefix + "_chr" + chr + "_" + idx + ".bcf.csi"
    File impute_log = output_prefix + "_chr" + chr + "_" + idx + ".log"
    File impute_time = "impute_chr" + chr + "_" + idx + ".time"
  }

  runtime {
    docker: "europe-docker.pkg.dev/finngen-sandbox-v3-containers/eu.gcr.io/glimpse"
    memory: imputation_ram + "G"
    cpu: imputation_threads
    disks: "local-disk " + imputation_storage + " SSD"
    zones: "europe-west1-b europe-west1-c europe-west1-d"
    preemptible: "3"
  }
}

task Ligate {
  input {
    Array[File] imputed_chunks
    Array[File] imputed_chunk_indexs
    String output_prefix
    String chr
    Int ligation_threads = 1
    Int ligation_ram = 4
    Int ligation_storage = 50
  }

  command <<<
    set -euo pipefail

    # List of imputed files to be ligated
    echo "~{sep='\n' imputed_chunks}" > imputed_chunks_list.txt

    OUT=~{output_prefix}_chr~{chr}.bcf

    # Ligate the chunks per chromosome
    /usr/bin/time -vo ligate_chr~{chr}.time \
    GLIMPSE2_ligate --input imputed_chunks_list.txt --output ${OUT} --threads ~{ligation_threads} --log ~{output_prefix}_chr~{chr}.log
  >>>

  output {
    File imputed_bcf = output_prefix + "_chr" + chr + ".bcf"
    File imputed_index = output_prefix + "_chr" + chr + ".bcf.csi"
    File ligate_log = output_prefix + "_chr" + chr + ".log"
    File ligate_time = "ligate_chr" + chr + ".time"
  }

  runtime {
    docker: "europe-docker.pkg.dev/finngen-sandbox-v3-containers/eu.gcr.io/glimpse"
    memory: ligation_ram + "G"
    cpu: ligation_threads
    disks: "local-disk " + ligation_storage + " SSD"
    zones: "europe-west1-b europe-west1-c europe-west1-d"
    preemptible: "3"
  }
}
