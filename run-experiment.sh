#!/bin/bash

echo "===== Defect and Complexity Analysis Experiment ====="

# Check if Defects4J is in PATH
if ! command -v defects4j &> /dev/null; then
  echo "Error: defects4j command not found. Make sure Defects4J is installed and in your PATH."
  echo "You might need to run: export PATH=\$PATH:/path/to/defects4j/framework/bin"
  exit 1
fi

# Check if PMD is installed
if ! command -v pmd &> /dev/null; then
  echo "Error: pmd command not found. Make sure PMD is installed."
  exit 1
fi

# Create required directories
mkdir -p data/projects data/results

# Step 1: Checkout projects
echo "Step 1: Checking out projects from Defects4J..."
./scripts/checkout-projects.sh

# Step 2: Analyze complexity and defects
echo "Step 2: Analyzing projects for complexity and defects..."
./scripts/analyze-complexity.sh

# Step 3: Perform statistical analysis
echo "Step 3: Performing correlation analysis..."
node src/correlation-analysis.js

# Step 4: Generate visualization
echo "Step 4: Generating visualization..."
node scripts/visualize-results.js

echo "Experiment completed! Results are available in the data/results directory."
echo "Open data/results/visualization.html in a web browser to see the visualization."