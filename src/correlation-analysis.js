const fs = require('fs');
const path = require('path');

// Read results file
const resultsPath = path.join(__dirname, '..', 'data', 'results', 'analysis-results.json');
const results = JSON.parse(fs.readFileSync(resultsPath, 'utf8'));

// Extract data for correlation analysis
const data = Object.values(results)
  .filter(result => result.avgComplexity !== 'N/A')
  .map(result => ({
    complexity: parseFloat(result.avgComplexity),
    defectDensity: parseFloat(result.defectDensity)
  }));

// Calculate Pearson correlation coefficient
function calculatePearsonCorrelation(data) {
  const n = data.length;
  
  // Calculate means
  const meanX = data.reduce((sum, item) => sum + item.complexity, 0) / n;
  const meanY = data.reduce((sum, item) => sum + item.defectDensity, 0) / n;
  
  // Calculate covariance and variances
  let covariance = 0;
  let varianceX = 0;
  let varianceY = 0;
  
  for (const item of data) {
    const diffX = item.complexity - meanX;
    const diffY = item.defectDensity - meanY;
    
    covariance += diffX * diffY;
    varianceX += diffX * diffX;
    varianceY += diffY * diffY;
  }
  
  // Calculate correlation coefficient
  const correlation = covariance / (Math.sqrt(varianceX) * Math.sqrt(varianceY));
  
  return correlation;
}

const correlation = calculatePearsonCorrelation(data);

console.log('Correlation Analysis Results:');
console.log('---------------------------');
console.log(`Pearson correlation coefficient: ${correlation.toFixed(4)}`);
console.log(`Strength of correlation: ${
  Math.abs(correlation) > 0.7 ? 'Strong' : 
  Math.abs(correlation) > 0.4 ? 'Moderate' : 'Weak'
}`);
console.log(`Direction: ${correlation > 0 ? 'Positive' : 'Negative'}`);

// Save analysis to file
const analysisResult = {
  pearsonCorrelation: correlation,
  strength: Math.abs(correlation) > 0.7 ? 'Strong' : Math.abs(correlation) > 0.4 ? 'Moderate' : 'Weak',
  direction: correlation > 0 ? 'Positive' : 'Negative',
  data
};

fs.writeFileSync(
  path.join(__dirname, '..', 'data', 'results', 'correlation-analysis.json'),
  JSON.stringify(analysisResult, null, 2)
);

console.log('Analysis saved to data/results/correlation-analysis.json');