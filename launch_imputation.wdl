version 1.0

import "bcf_imputation.wdl" as bcf_imputation

# Run bcf_imputation.wdl over multiple chromosomes

#### Workflow part ####
workflow WG_imputation {
  input {
    Array[String] chromosomes
    File bam_list
    String chunkfile_pre
    String chunkfile_suf
    String refpanel_pre
    String refpanel_suf
    String map_pre
    String map_suf
    String output_prefix
    Int imputation_threads = 1
    Int imputation_ram = 4
    Int imputation_storage = 50
    Int ligation_threads = 1
    Int ligation_ram = 4
    Int ligation_storage = 50
  }

  scatter (chr in chromosomes) {
    call bcf_imputation.impute {
      input:
        bam_list = bam_list,
        chunk_file = chunkfile_pre + chr + chunkfile_suf,
        ref_panel = refpanel_pre + chr + refpanel_suf,
        map = map_pre + chr + map_suf,
        output_prefix = output_prefix,
        chr = chr,
        imputation_threads = imputation_threads,
        imputation_ram = imputation_ram,
        imputation_storage = imputation_storage,
        ligation_threads = ligation_threads,
        ligation_ram = ligation_ram,
        ligation_storage = ligation_storage
    }
  }

  output {
    Array[File] imputed = impute.imputed_bcf
    Array[File] imputed_index = impute.imputed_index
    Array[Array[File]] impute_log = impute.impute_log_output
    Array[File] ligate_log = impute.ligate_log_output
    Array[Array[File]] impute_time = impute.impute_time_output
    Array[File] ligate_time = impute.ligate_time_output
  }
}
