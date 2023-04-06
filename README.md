# Barcode Processing Pipeline

This pipeline processes paired-end FASTQ files and extracts barcode counts. It consists of the following steps:

1. Process FASTQ files and generate a shell script (map_it_all.sh) containing the `seal.sh` commands for each pair of input files.
2. Run concurrent `seal.sh` jobs using the generated script.
3. Generate overall counts from the output statistics files.
4. Generate barcode metadata.
5. Sort and join the overall counts and barcode metadata files.

## Usage

```bash
./process_barcodes.sh <barcodes.fasta>
```

## Prerequisites

- BBMap tools installed and available in the PATH (specifically `seal.sh`)
- Paired-end FASTQ files present in the same directory as the script

## Input

- A FASTA file containing barcodes (`barcodes.fasta`)

## Output

- `map_it_all.sh`: Shell script containing `seal.sh` commands for each pair of input files
- `Barcodes_stats` directory: Contains output statistics files for each pair of input files
- `overall_counts.tsv`: Tab-separated file with overall counts for each barcode and sample
- `barcode_metadata.tsv`: Tab-separated file with metadata for each sample
- `overall_counts_with_metadata.tsv`: Tab-separated file with overall counts and metadata combined
