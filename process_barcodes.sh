#!/bin/bash
# This script processes fastq files, creates concurrent jobs, generates overall counts, 
# generates barcode metadata and sorts & joins files.
# Expected input is a fasta file of barcodes.
# Example usage: ./script.sh barcodes.fasta

set -e

# Processes each fastq file in the current directory
function process_fastq_files() {
    local barcodes_fasta="$1"
    local escaped_barcodes_fasta=$(echo "$barcodes_fasta" | sed 's/ /\\ /g')

    for file in *R1*gz; do
        local forward="$file"
        local reverse=$(echo "$forward" | sed 's/R1/R2/g')
        local barcode_set=$(echo "$forward" | sed 's/\_.*//g').seal.tsv
        echo "/home/glbrc.org/ryan.d.ward/.bin/seal.sh overwrite=t in1=\"$forward\" in2=\"$reverse\" k=20 mm=f t=4 ambiguous=toss hdist=0 trd=t rename fbm int=f ref=\"$escaped_barcodes_fasta\" stats=\"Barcodes_stats/$barcode_set\""
    done > map_it_all.sh
}

# Creates and runs concurrent jobs from a given input file
function run_concurrent_jobs() {
    local input_file="$1"
    local max_jobs="$2"
    local commands=()
    local index=0

    while IFS= read -r line || [ -n "$line" ]; do
        commands+=("$line")
    done < "$input_file"

    for command in "${commands[@]}"; do
        (
            eval "$command"
        ) &

        if (( ++index % max_jobs == 0 )); then
            wait
        fi
    done

    wait
}

# Generates overall counts from stats files
function generate_overall_counts() {
    awk 'BEGIN{OFS="\t"; print "guide","count","sample"}' > overall_counts.tsv
    for stats_file in Barcodes_stats/*seal.tsv; do
        local sample=${stats_file%%.*}; sample=${sample##"Barcodes_stats/"};
        gawk -v OFS='\t' -vsample=$sample '$0!~"#"{print $1, $2/2, sample}' $stats_file;
    done >> overall_counts.tsv
}

# Generates barcode metadata from stats files
function generate_barcode_metadata() {
    for stats_file in Barcodes_stats/*seal.tsv; do
        local sample=$(basename $stats_file .seal.tsv)
        gawk -v sample=$sample 'NF == 3 && $0 ~ "^#" {gsub("#", "", $1); print sample, $1, $2}' $stats_file;
    done | 
    gawk 'BEGIN{OFS="\t"; print "sample","matched","total"} $2 == "Matched" {matched[$1] = $3} $2 == "Total" {total[$1] = $3} END {for (sample in matched) {print sample, matched[sample], total[sample]}}' > barcode_metadata.tsv
}

# Sorts and joins files
function sort_and_join_files() {
    awk 'NR == 1; NR > 1 {print $0 | "LANG=en_EN && sort -k 1,1V"}' barcode_metadata.tsv > barcode_metadata.sorted.tsv && mv barcode_metadata.sorted.tsv barcode_metadata.tsv
    awk 'NR == 1; NR > 1 {print $0 | "LANG=en_EN && sort -k 3,3V -k 2,2nr"}' overall_counts.tsv > overall_counts.sorted.tsv && mv overall_counts.sorted.tsv overall_counts.tsv
    join -t $'\t' -13 -21 overall_counts.tsv barcode_metadata.tsv  > overall_counts_with_metadata.tsv
}

# Main function
function main() {
    if [ $# -ne 1 ]; then
        echo "Usage: $0 <barcodes.fasta>"
        echo "Expected <barcodes.fasta> is a fasta file containing barcode sequences"
        exit 1
    fi

    local barcodes_fasta="$(realpath "$1")"
    local concurrent_jobs=8
    process_fastq_files "$barcodes_fasta"
    run_concurrent_jobs map_it_all.sh "$concurrent_jobs"
    generate_overall_counts
    generate_barcode_metadata
    sort_and_join_files
}

main "$@"
