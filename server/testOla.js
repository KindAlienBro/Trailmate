require('dotenv').config();
const axios = require('axios');
async function run() {
  const apiKey = process.env.OLA_MAPS_API_KEY;
  console.log('Key:', apiKey ? 'Loaded' : 'Missing');
  const origin = "12.9716,77.5946"; // Bangalore
  const destination = "16.6978,74.8329"; // Ugar Khurd
  const url = `https://api.olamaps.io/routing/v1/directions?origin=${origin}&destination=${destination}&api_key=${apiKey}&steps=true&alternatives=true`;
  try {
    const res = await axios.post(url);
    console.log('Routes count:', res.data.routes ? res.data.routes.length : 0);
  } catch(e) {
    console.log('Error:', e.response ? e.response.data : e.message);
  }
}
run();
