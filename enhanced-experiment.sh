#!/bin/bash
# enhanced-experiment.sh
# Script to analyze complexity differences between buggy and fixed versions

# Create necessary directories
mkdir -p data/complexity-comparison
mkdir -p data/results

PMD_CACHE_FILE=".pmd-cache.bin"

# Define projects to analyze
PROJECTS=("Closure" "Collections" "Lang" "Math" "Mockito" "Time")

# Function to calculate complexity for a specific version of a project
calculate_complexity() {
  local project=$1
  local version_id=$2
  local version_type=$3  # 'b' for buggy, 'f' for fixed
  local output_dir="data/complexity-comparison/${project}"
  
  mkdir -p "${output_dir}"
  
  echo "Analyzing ${project} - Version ${version_id}${version_type}..."
  
  # Create a temporary directory for the checkout
  local temp_dir="data/temp/${project}_${version_id}${version_type}"
  mkdir -p "${temp_dir}"
  
  # Checkout the specific version
  defects4j checkout -p "${project}" -v "${version_id}${version_type}" -w "${temp_dir}"
  
  # Get list of modified files between buggy and fixed
  if [ "${version_type}" = "f" ]; then
    local modified_files=$(defects4j export -p classes.modified -w "${temp_dir}" -o "${output_dir}/modified_files_${version_id}.txt")
    echo "Modified files for ${project}-${version_id}: ${modified_files}"
  fi
  
  # Run PMD complexity analysis on the whole project
  pmd_output=$(pmd check -d "${temp_dir}" -R category/java/design.xml/CyclomaticComplexity -f csv --cache "${PMD_CACHE_FILE}" > "${output_dir}/${version_id}${version_type}_complexity.csv")
  
  # If we have the list of modified files, also analyze them separately
  if [ "${version_type}" = "f" ] && [ -f "${output_dir}/modified_files_${version_id}.txt" ]; then
    echo "Analyzing modified files specifically..."
    
    # Extract class names from the modified files list
    local classes=$(cat "${output_dir}/modified_files_${version_id}.txt" | tr ',' '\n')
    
    # Convert class names to file paths
    for class in $classes; do
      # Convert package notation to file path
      local file_path=$(echo "${class}" | tr '.' '/')
      echo "Looking for modified file: ${file_path}.java"
      
      # Find the actual file
      local found_file=$(find "${temp_dir}" -name "$(basename ${file_path}).java")
      
      if [ -n "${found_file}" ]; then
        echo "Analyzing modified file: ${found_file}"
        # Run PMD on the specific file
        pmd check -d "${found_file}" -R category/java/design.xml/CyclomaticComplexity -f csv --cache "${PMD_CACHE_FILE}" >> "${output_dir}/${version_id}_modified_files_complexity.csv"
      fi
    done
  fi
}

# Main analysis loop
for project in "${PROJECTS[@]}"; do
  echo "Processing project: ${project}"
  
  # Get the number of bugs for this project
  num_bugs=$(defects4j info -p "${project}" | grep "Number of bugs" | awk '{print $4}')
  echo "${project} has ${num_bugs} bugs"
  
  # For each bug, analyze both buggy and fixed versions
  for ((bug=1; bug<=${num_bugs}; bug++)); do
    echo "Analyzing bug ${bug} for ${project}"
    
    # Calculate complexity for buggy version
    calculate_complexity "${project}" "${bug}" "b"
    
    # Calculate complexity for fixed version
    calculate_complexity "${project}" "${bug}" "f"
    
    echo "Completed analysis for ${project} bug ${bug}"
  done
done

# Create comparison script
cat > src/compare-complexity.js << 'EOF'
const fs = require('fs');
const path = require('path');
const Papa = require('papaparse'); // You'll need to install this: npm install papaparse

// Define projects
const PROJECTS = ['Closure', 'Collections', 'Lang', 'Math', 'Mockito', 'Time'];

// Function to parse CSV files
function parseCSV(filePath) {
  if (!fs.existsSync(filePath)) {
    return [];
  }
  
  const fileContent = fs.readFileSync(filePath, 'utf8');
  const results = Papa.parse(fileContent, {
    header: true,
    skipEmptyLines: true,
    dynamicTyping: true
  });
  
  return results.data;
}

// Results structure
const results = {
  overall: {
    complexityIncreased: 0,
    complexityDecreased: 0,
    complexityUnchanged: 0,
    totalDefects: 0
  },
  byProject: {}
};

// Process each project
PROJECTS.forEach(project => {
  console.log(`Processing ${project}...`);
  
  const projectDir = path.join(__dirname, '..', 'data', 'complexity-comparison', project);
  
  if (!fs.existsSync(projectDir)) {
    console.log(`  No data for ${project}, skipping`);
    return;
  }
  
  // Initialize project stats
  results.byProject[project] = {
    complexityIncreased: 0,
    complexityDecreased: 0,
    complexityUnchanged: 0,
    totalDefects: 0,
    defects: []
  };
  
  // Get all the file pairs for analysis
  const files = fs.readdirSync(projectDir);
  const buggyFiles = files.filter(f => f.match(/\d+b_complexity\.csv$/));
  
  // For each buggy version, find the corresponding fixed version
  buggyFiles.forEach(buggyFile => {
    const bugId = buggyFile.match(/(\d+)b_complexity/)[1];
    const fixedFile = buggyFile.replace('b_complexity.csv', 'f_complexity.csv');
    const modifiedFile = `${bugId}_modified_files_complexity.csv`;
    
    console.log(`  Analyzing defect ${bugId}...`);
    
    // Parse the CSV data
    const buggyData = parseCSV(path.join(projectDir, buggyFile));
    const fixedData = parseCSV(path.join(projectDir, fixedFile));
    const modifiedData = parseCSV(path.join(projectDir, modifiedFile));
    
    // Calculate average complexity for buggy version
    const buggyComplexity = buggyData.reduce((sum, row) => {
      return sum + (row['cyclomatic complexity'] || 0);
    }, 0) / (buggyData.length || 1);
    
    // Calculate average complexity for fixed version
    const fixedComplexity = fixedData.reduce((sum, row) => {
      return sum + (row['cyclomatic complexity'] || 0);
    }, 0) / (fixedData.length || 1);
    
    // Calculate average complexity for modified files only
    const modifiedComplexity = modifiedData.length ? modifiedData.reduce((sum, row) => {
      return sum + (row['cyclomatic complexity'] || 0);
    }, 0) / modifiedData.length : 'N/A';
    
    // Determine if complexity increased, decreased, or stayed the same
    let complexityChange;
    if (buggyComplexity < fixedComplexity) {
      complexityChange = 'increased';
      results.overall.complexityIncreased++;
      results.byProject[project].complexityIncreased++;
    } else if (buggyComplexity > fixedComplexity) {
      complexityChange = 'decreased';
      results.overall.complexityDecreased++;
      results.byProject[project].complexityDecreased++;
    } else {
      complexityChange = 'unchanged';
      results.overall.complexityUnchanged++;
      results.byProject[project].complexityUnchanged++;
    }
    
    results.overall.totalDefects++;
    results.byProject[project].totalDefects++;
    
    // Store detailed defect info
    results.byProject[project].defects.push({
      id: bugId,
      buggyComplexity: buggyComplexity.toFixed(2),
      fixedComplexity: fixedComplexity.toFixed(2),
      modifiedFilesComplexity: modifiedComplexity !== 'N/A' ? modifiedComplexity.toFixed(2) : 'N/A',
      complexityChange,
      percentChange: ((fixedComplexity - buggyComplexity) / buggyComplexity * 100).toFixed(2)
    });
  });
});

// Calculate percentages
results.overall.percentIncreased = (results.overall.complexityIncreased / results.overall.totalDefects * 100).toFixed(2);
results.overall.percentDecreased = (results.overall.complexityDecreased / results.overall.totalDefects * 100).toFixed(2);
results.overall.percentUnchanged = (results.overall.complexityUnchanged / results.overall.totalDefects * 100).toFixed(2);

// Write results to file
fs.writeFileSync(
  path.join(__dirname, '..', 'data', 'results', 'complexity-comparison-results.json'),
  JSON.stringify(results, null, 2)
);

// Generate HTML report
const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <title>Complexity Changes After Bug Fixes</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    .chart-container { width: 800px; height: 400px; margin-bottom: 30px; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
    .positive { color: #d9534f; }
    .negative { color: #5cb85c; }
    .neutral { color: #f0ad4e; }
  </style>
</head>
<body>
  <h1>Complexity Changes After Bug Fixes</h1>
  
  <h2>Overall Results</h2>
  <p>
    <strong>Total defects analyzed:</strong> ${results.overall.totalDefects}<br>
    <strong>Complexity increased:</strong> ${results.overall.complexityIncreased} (${results.overall.percentIncreased}%)<br>
    <strong>Complexity decreased:</strong> ${results.overall.complexityDecreased} (${results.overall.percentDecreased}%)<br>
    <strong>Complexity unchanged:</strong> ${results.overall.complexityUnchanged} (${results.overall.percentUnchanged}%)
  </p>
  
  <div class="chart-container">
    <canvas id="overallChart"></canvas>
  </div>
  
  <h2>Results by Project</h2>
  
  ${Object.entries(results.byProject).map(([project, data]) => `
    <h3>${project}</h3>
    <p>
      <strong>Total defects analyzed:</strong> ${data.totalDefects}<br>
      <strong>Complexity increased:</strong> ${data.complexityIncreased} (${(data.complexityIncreased / data.totalDefects * 100).toFixed(2)}%)<br>
      <strong>Complexity decreased:</strong> ${data.complexityDecreased} (${(data.complexityDecreased / data.totalDefects * 100).toFixed(2)}%)<br>
      <strong>Complexity unchanged:</strong> ${data.complexityUnchanged} (${(data.complexityUnchanged / data.totalDefects * 100).toFixed(2)}%)
    </p>
    
    <h4>Defect Details</h4>
    <table>
      <tr>
        <th>Defect ID</th>
        <th>Buggy Complexity</th>
        <th>Fixed Complexity</th>
        <th>Modified Files Complexity</th>
        <th>Change</th>
        <th>Percent Change</th>
      </tr>
      ${data.defects.map(defect => `
        <tr>
          <td>${defect.id}</td>
          <td>${defect.buggyComplexity}</td>
          <td>${defect.fixedComplexity}</td>
          <td>${defect.modifiedFilesComplexity}</td>
          <td class="${defect.complexityChange === 'increased' ? 'positive' : (defect.complexityChange === 'decreased' ? 'negative' : 'neutral')}">${defect.complexityChange}</td>
          <td class="${parseFloat(defect.percentChange) > 0 ? 'positive' : (parseFloat(defect.percentChange) < 0 ? 'negative' : 'neutral')}">${defect.percentChange}%</td>
        </tr>
      `).join('')}
    </table>
  `).join('')}
  
  <script>
    // Create overall chart
    const ctx = document.getElementById('overallChart').getContext('2d');
    const chart = new Chart(ctx, {
      type: 'pie',
      data: {
        labels: ['Increased', 'Decreased', 'Unchanged'],
        datasets: [{
          data: [${results.overall.complexityIncreased}, ${results.overall.complexityDecreased}, ${results.overall.complexityUnchanged}],
          backgroundColor: [
            'rgba(217, 83, 79, 0.7)',
            'rgba(92, 184, 92, 0.7)',
            'rgba(240, 173, 78, 0.7)'
          ],
          borderColor: [
            'rgba(217, 83, 79, 1)',
            'rgba(92, 184, 92, 1)',
            'rgba(240, 173, 78, 1)'
          ],
          borderWidth: 1
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            position: 'top',
          },
          title: {
            display: true,
            text: 'Complexity Changes After Bug Fixes'
          }
        }
      }
    });
  </script>
</body>
</html>
`;

fs.writeFileSync(
  path.join(__dirname, '..', 'data', 'results', 'complexity-comparison-report.html'),
  htmlContent
);

console.log('Analysis complete! Results saved to:');
console.log('- data/results/complexity-comparison-results.json');
console.log('- data/results/complexity-comparison-report.html');
EOF

# Install required packages
npm install papaparse

# Run comparison analysis
node src/compare-complexity.js

echo "Enhanced analysis complete!"
echo "Results available in data/results/complexity-comparison-report.html"