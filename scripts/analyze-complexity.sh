#!/bin/bash

# Create PMD cache directory
mkdir -p .pmd-cache

# Create results directory
mkdir -p data/results

# Create JSON file to store results
echo "{" > data/results/analysis-results.json

# Define projects
PROJECTS=("Closure" "Collections" "Lang" "Math" "Mockito" "Time")

# Analyze each project
for i in "${!PROJECTS[@]}"; do
  project=${PROJECTS[$i]}
  echo "Analyzing $project..."
  
  # Project path
  project_path="data/projects/$project"
  
  # Skip if project doesn't exist
  if [ ! -d "$project_path" ]; then
    echo "Warning: $project directory not found, skipping..."
    continue
  fi
  
  # Count lines of code
  loc=$(find "$project_path" -name "*.java" | xargs wc -l | tail -n 1 | awk '{print $1}')
  
  # Get defect count from the info file
  defect_count=$(grep "Number of bugs" data/results/${project}_info.txt | awk '{print $4}')
  
  # Calculate defect density (defects per KLOC)
  defect_density=$(echo "scale=2; $defect_count / ($loc / 1000)" | bc | awk '{printf "%.2f", $0}')
  
  # Run PMD for cyclomatic complexity
  pmd_output=$(pmd check -d "$project_path" -R category/java/design.xml/CyclomaticComplexity -f text --cache .pmd-cache)
  
  # Extract complexity values
  complexity_values=$(echo "$pmd_output" | grep -o "cyclomatic complexity of [0-9]*" | grep -o "[0-9]*")
  
  # Calculate average complexity
  if [ -n "$complexity_values" ]; then
    total=0
    count=0
    
    for value in $complexity_values; do
      total=$((total + value))
      count=$((count + 1))
    done
    
    avg_complexity=$(echo "scale=2; $total / $count" | bc)
  else
    avg_complexity="N/A"
  fi
  
  # Append to results JSON
  echo "  \"$project\": {" >> data/results/analysis-results.json
  echo "    \"loc\": $loc," >> data/results/analysis-results.json
  echo "    \"defectCount\": $defect_count," >> data/results/analysis-results.json
  echo "    \"defectDensity\": $defect_density," >> data/results/analysis-results.json
  echo "    \"avgComplexity\": \"$avg_complexity\"" >> data/results/analysis-results.json
  
  # Add comma if not the last project
  if [ $i -lt $((${#PROJECTS[@]} - 1)) ]; then
    echo "  }," >> data/results/analysis-results.json
  else
    echo "  }" >> data/results/analysis-results.json
  fi
  
  echo "Completed analysis for $project"
done

# Close the JSON object
echo "}" >> data/results/analysis-results.json

echo "Analysis complete! Results saved to data/results/analysis-results.json"