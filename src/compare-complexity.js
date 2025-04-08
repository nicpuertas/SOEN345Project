const fs = require('fs');
const path = require('path');
const Papa = require('papaparse'); // You'll need to install this: npm install papaparse

// Define projects
const PROJECTS = ['Closure', 'Collections', 'Lang', 'Math', 'Mockito', 'Time'];

// Helper function to safely extract complexity from any row format
function extractComplexity(row) {
  // Handle different types of row data
  if (!row) return 0;
  
  let message = '';
  
  if (typeof row === 'object' && row !== null) {
    // Try different field names for the message
    for (const key of Object.keys(row)) {
      if (typeof row[key] === 'string' && 
          row[key].includes('cyclomatic complexity')) {
        message = row[key];
        break;
      }
    }
    
    // If we couldn't find it in named fields, try numeric indices
    if (!message) {
      for (let i = 0; i < 10; i++) {
        if (typeof row[i] === 'string' && 
            row[i].includes('cyclomatic complexity')) {
          message = row[i];
          break;
        }
      }
    }
  } else if (typeof row === 'string') {
    message = row;
  }
  
  // Extract the complexity value
  const match = message.match(/cyclomatic complexity of (\d+)/);
  return match ? parseInt(match[1], 10) : 0;
}

// Function to parse CSV files
function parseCSV(filePath) {
  if (!fs.existsSync(filePath)) {
    console.log(`File not found: ${filePath}`);
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
    const buggyComplexity = buggyData.reduce((sum, row) => 
      sum + extractComplexity(row), 0) / (buggyData.length || 1);
    
    // Calculate average complexity for fixed version
    const fixedComplexity = fixedData.reduce((sum, row) => 
      sum + extractComplexity(row), 0) / (fixedData.length || 1);
    
    // Calculate average complexity for modified files only
    const modifiedComplexity = modifiedData.length ? 
      modifiedData.reduce((sum, row) => sum + extractComplexity(row), 0) / modifiedData.length : 
      'N/A';
    
    // Output debug info
    console.log(`  Defect ${bugId}: Buggy=${buggyComplexity.toFixed(2)}, Fixed=${fixedComplexity.toFixed(2)}`);
    
    // Determine if complexity increased, decreased, or stayed the same
    // Use a small threshold to account for floating point imprecision
    const threshold = 0.02;
    let complexityChange;
    
    if (buggyComplexity + threshold < fixedComplexity) {
      complexityChange = 'increased';
      results.overall.complexityIncreased++;
      results.byProject[project].complexityIncreased++;
    } else if (buggyComplexity > fixedComplexity + threshold) {
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
if (results.overall.totalDefects > 0) {
  results.overall.percentIncreased = (results.overall.complexityIncreased / results.overall.totalDefects * 100).toFixed(2);
  results.overall.percentDecreased = (results.overall.complexityDecreased / results.overall.totalDefects * 100).toFixed(2);
  results.overall.percentUnchanged = (results.overall.complexityUnchanged / results.overall.totalDefects * 100).toFixed(2);
}

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