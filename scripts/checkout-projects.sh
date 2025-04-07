#!/bin/bash

# Define projects to analyze
PROJECTS=("Closure" "Collections" "Lang" "Math" "Mockito" "Time")

# Create projects directory
mkdir -p data/projects

# Checkout each project
for project in "${PROJECTS[@]}"; do
  echo "Checking out $project..."
  
  # Get project info
  defects4j info -p $project > data/results/${project}_info.txt
  
  # Extract bug count
  num_bugs=$(grep "Number of bugs" data/results/${project}_info.txt | awk '{print $4}')
  
  # Checkout fixed version of first bug
  defects4j checkout -p $project -v 1f -w data/projects/$project
  
  echo "Checked out $project with $num_bugs bugs"
done

echo "All projects checked out successfully"