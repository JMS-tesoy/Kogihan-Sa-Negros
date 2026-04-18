const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  try {
    console.log('Navigating to http://localhost:3000...');
    await page.goto('http://localhost:3000', { 
      waitUntil: 'networkidle', 
      timeout: 30000 
    });
    
    const screenshotPath = 'C:/Users/Lenovo/.gemini/tmp/family-tree/homepage.png';
    await page.screenshot({ path: screenshotPath, fullPage: true });
    
    const title = await page.title();
    const content = await page.innerText('body');
    
    console.log('SUCCESS');
    console.log('Title:', title);
    console.log('Screenshot saved to:', screenshotPath);
    console.log('Body snippet:', content.substring(0, 200).replace(/\n/g, ' '));
  } catch (error) {
    console.error('ERROR:', error.message);
    process.exit(1);
  } finally {
    await browser.close();
  }
})();
