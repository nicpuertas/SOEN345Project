# Defect Density and Cyclomatic Complexity Analysis

This project investigates the relationship between cyclomatic complexity and defect density in Java projects from the Defects4J repository. The experiment tests whether higher code complexity correlates with higher defect rates.

## Hypothesis

Projects with a high cyclomatic complexity will also have a high density of defects.

## Prerequisites

- Java JDK (11 or higher)
- Node.js (14 or higher)
- PMD (installed via Homebrew)
- Defects4J

## Setup Instructions

### 1. Clone this repository

```bash
git clone https://github.com/nicpuertas/SOEN345Project
cd Project
```

### 2. Install and configure Defects4J

```bash
# Clone Defects4J repository
git clone https://github.com/rjust/defects4j.git

# Move to the defects4j directory
cd defects4j

# Run the initialization script
./init.sh

# Return to the main directory
cd ..

# Add Defects4J to your PATH
export PATH=$PATH:$(pwd)/defects4j/framework/bin
```

### 3. Install PMD (if not already installed)

```bash
# Using Homebrew
brew install pmd
```

### 4. Directory Structure

Ensure you have the following directory structure:
```
.
├── defects4j/             # The Defects4J framework
├── data/
│   ├── projects/          # Will store checked-out projects 
│   ├── results/           # Will store analysis results
│   └── complexity-comparison       # Will store complexity-comparison results           
├── scripts/               # Contains shell scripts for analysis
│   ├── checkout-projects.sh
│   ├── analyze-complexity.sh
│   └── visualize-results.js
├── src/                   # Contains JavaScript analysis scripts
│   ├──  correlation-analysis.js
│   └──  compare-complexity.js
├── run-experiment.sh      # Main execution script
└── enhanced-experiment.sh # Second execution script
```

## Running the Experiment

Run the complete experiment with:

```bash
./run-experiment.sh
```

This script will:
1. Check if requirements are installed
2. Check out selected Java projects from Defects4J
3. Calculate cyclomatic complexity for each project using PMD
4. Calculate defect density (defects per KLOC)
5. Analyze the correlation between complexity and defect density
6. Generate visualizations of the results

## Viewing Results

After running the experiment:

1. Open `data/results/visualization.html` in a web browser to see the graphical representation
2. Check `data/results/correlation-analysis.json` for the Pearson correlation coefficient
3. Review `data/results/analysis-results.json` for raw data on each project

## Modifying the Project Set

To analyze a different set of projects:

1. Edit `scripts/checkout-projects.sh` and `scripts/analyze-complexity.sh`
2. Modify the `PROJECTS` array to include the desired projects
3. Run the experiment again

## Troubleshooting

- **Defects4J not found**: Ensure Defects4J is in your PATH
- **PMD errors**: Verify PMD is installed correctly (`pmd --version`)
- **JSON parsing errors**: Check that decimal values are properly formatted in output files
- **Missing projects**: Verify project names match those available in Defects4J

## Project Files Explanation

- **checkout-projects.sh**: Checks out selected Java projects from Defects4J
- **analyze-complexity.sh**: Calculates cyclomatic complexity and defect density
- **correlation-analysis.js**: Computes Pearson correlation between complexity and defect density
- **visualize-results.js**: Generates an HTML visualization of the results
- **run-experiment.sh**: Orchestrates the entire experiment workflow

