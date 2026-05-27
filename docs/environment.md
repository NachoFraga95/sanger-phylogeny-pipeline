# Environment Setup

## Requirements

This pipeline was developed and tested on Ubuntu 20.04 (WSL2) with the following tools:

## Conda environment

Create the `sanger` environment with all required dependencies:

```bash
mamba create -n sanger -c conda-forge -c bioconda \
    python=3.11 \
    biopython \
    trimmomatic \
    fastqc \
    multiqc \
    mafft \
    muscle \
    clustalw \
    -y
```

Then activate it:

```bash
conda activate sanger
```

## Key tools and versions
| Tool | Version | Purpose |
|------|---------|---------|
| Python | 3.11 | Scripting |
| Biopython | latest | AB1 parsing, sequence handling |
| FastQC | 0.12.1 | Quality control |
| Trimmomatic | latest | Trimming and clipping |
| MAFFT | 7.526 | Multiple sequence alignment |
| MUSCLE | latest | Alternative alignment |
| ClustalW | latest | Alternative alignment |

## External tools
- **Geneious** — manual inspection and primer classification
- **iTOL** (Interactive Tree of Life) — tree visualization and annotation
- **MEGA** — tree inference and visualization

## Notes
- Raw AB1 files are not included in this repository due to size
- Metadata files in `data/meta/` describe sample provenance and marker assignments
