const fs = require('fs');
const path = require('path');

// Read results
const resultsPath = path.join(__dirname, '..', 'data', 'results', 'analysis-results.json');
const results = JSON.parse(fs.readFileSync(resultsPath, 'utf8'));

// Generate HTML for visualization
const htmlContent = `
<!DOCTYPE html>
<html>
<head>
  <title>Defect Density vs. Cyclomatic Complexity Analysis</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
  <style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    .chart-container { width: 800px; height: 500px; }
    table { border-collapse: collapse; width: 100%; margin-top: 20px; }
    th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
    th { background-color: #f2f2f2; }
  </style>
</head>
<body>
  <h1>Defect Density vs. Cyclomatic Complexity Analysis</h1>
  
  <div class="chart-container">
    <canvas id="correlationChart"></canvas>
  </div>
  
  <h2>Project Data</h2>
  <table>
    <tr>
      <th>Project</th>
      <th>Lines of Code</th>
      <th>Defect Count</th>
      <th>Defect Density (per KLOC)</th>
      <th>Avg. Cyclomatic Complexity</th>
    </tr>
    ${Object.entries(results).map(([project, data]) => `
      <tr>
        <td>${project}</td>
        <td>${data.loc.toLocaleString()}</td>
        <td>${data.defectCount}</td>
        <td>${data.defectDensity}</td>
        <td>${data.avgComplexity}</td>
      </tr>
    `).join('')}
  </table>
  
  <script>
    // Create scatter plot
    const ctx = document.getElementById('correlationChart').getContext('2d');
    const chart = new Chart(ctx, {
      type: 'scatter',
      data: {
        datasets: [{
          label: 'Projects',
          data: [
            ${Object.entries(results)
              .filter(([_, data]) => data.avgComplexity !== 'N/A')
              .map(([project, data]) => `{
                x: ${data.avgComplexity},
                y: ${data.defectDensity},
                label: '${project}'
              }`).join(',')}
          ],
          backgroundColor: 'rgba(54, 162, 235, 0.7)',
          borderColor: 'rgba(54, 162, 235, 1)',
          borderWidth: 1
        }]
      },
      options: {
        scales: {
          x: {
            title: {
              display: true,
              text: 'Average Cyclomatic Complexity'
            }
          },
          y: {
            title: {
              display: true,
              text: 'Defect Density (defects per KLOC)'
            }
          }
        },
        plugins: {
          tooltip: {
            callbacks: {
              label: function(context) {
                const point = context.raw;
                return \`\${point.label}: (Complexity: \${point.x}, Defect Density: \${point.y})\`;
              }
            }
          }
        }
      }
    });
  </script>
</body>
</html>
`;

// Write HTML file
fs.writeFileSync(
  path.join(__dirname, '..', 'data', 'results', 'visualization.html'),
  htmlContent
);

console.log('Visualization generated at data/results/visualization.html');