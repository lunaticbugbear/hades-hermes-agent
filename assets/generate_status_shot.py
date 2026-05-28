with open('/home/idx-332/hdi/assets/hades-status.svg', 'w') as f:
    f.write('''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 650 220" width="650" height="220">
  <style>
    .bg { fill: #0d1117; }
    .text { font-family: 'Cascadia Code', 'Fira Code', 'Courier New', monospace; font-size: 14px; fill: #c9d1d9; }
    .cmd { fill: #58a6ff; font-weight: bold; }
    .prompt { fill: #3fb950; font-weight: bold; }
    .info { fill: #8b949e; }
    .success { fill: #56d364; }
  </style>
  <rect width="100%" height="100%" rx="8" class="bg"/>
  <circle cx="20" cy="20" r="6" fill="#ff5f56"/>
  <circle cx="40" cy="20" r="6" fill="#ffbd2e"/>
  <circle cx="60" cy="20" r="6" fill="#27c93f"/>
  
  <text x="20" y="55" class="text"><tspan class="prompt">$</tspan> <tspan class="cmd">hades status</tspan></text>
  <text x="20" y="80" class="text">Container:   <tspan class="success">hades-gateway-1 (Running)</tspan></text>
  <text x="20" y="100" class="text">API Port:    8642</text>
  <text x="20" y="120" class="text">Provider:    openrouter</text>
  <text x="20" y="140" class="text">Model:       deepseek/deepseek-v4-flash:free</text>
  <text x="20" y="160" class="text">Agent State: <tspan class="success">READY</tspan></text>
  
  <text x="20" y="195" class="text"><tspan class="prompt">$</tspan> <tspan class="cmd">hades cli</tspan></text>
</svg>''')
