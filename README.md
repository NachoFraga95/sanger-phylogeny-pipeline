# Sanger Phylogeny Pipeline

A complete Sanger sequencing QC, assembly, and phylogenetic tree pipeline developed for the FONDECYT Regular Project Nº 1231713 - Laboratory of Plant Molecular Ecology, Universidad del Biobío, Chile.

## Biological context
Phylogenetic analysis of Chilean amphibians (*Eupsophus*, *Pleurodema*, *Alsodes*) using multiple molecular markers: 12S, 16S, COI, CRY, CYTB, DLOOP, POMC, RHOD.

## Pipeline overview
- `00_basecall.sh` — AB1 basecalling and initial QC
- `01_trim_clip.sh` — Trimming and clipping
- `02_consensus.py` — Consensus sequence generation
- `03_collect_markers.sh` — Marker collection and organization
- `04_align.sh` — Multiple sequence alignment (MAFFT/MUSCLE)
- `05_trees.sh` — Phylogenetic tree inference
- iTOL annotation files for tree visualization

## Requirements
See `docs/environment.md` for dependencies and conda environment setup.

## Author
Jorge Ignacio Fraga Pérez  
Biochemist | Bioinformatics  
ignaciofraga.p@gmail.com
