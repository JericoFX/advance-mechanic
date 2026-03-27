const GTA_COLORS = [
    '#0d1116', '#1c1d21', '#32383d', '#454b4f', '#999da0', '#c2c4c6', '#979a97', '#637380',
    '#63625c', '#3c3f47', '#444e54', '#1d2129', '#13181f', '#26282a', '#515554', '#151921',
    '#1e2529', '#3b3e42', '#555e5d', '#848988', '#585853', '#6c6b7a', '#585853', '#545c5e',
    '#090c13', '#0c0d11', '#0e0d13', '#272b30', '#2b3036', '#656a5f', '#555551', '#40453a',
    '#3f4247', '#3e3d3f', '#1e232c', '#1f2a33', '#273037', '#333e48', '#49525e', '#5a636a',
    '#84888b', '#191e24', '#2b2e33', '#2d3137', '#393d42', '#474c52', '#5e6267', '#81868a',
    '#0a0c0e', '#1a1e23', '#2f3338', '#3c4045', '#474b4e', '#585c5f', '#6b6e71', '#868a8d',
    '#c00e1a', '#da1918', '#b6111b', '#a51e23', '#7b1a22', '#8b1a1f', '#611118', '#4b0f14',
    '#840010', '#6c0c15', '#5a0b11', '#6b0814', '#450a10', '#781124', '#8f1729', '#6f0a15',
    '#d44b17', '#e16024', '#d6842d', '#e08f39', '#d9a23b', '#e6b860', '#f5da7a', '#edcf60',
    '#e2c651', '#d3b84b', '#b3993e', '#a08c3a', '#7d6c29', '#4d4c2e', '#3b3924', '#2f2f29',
    '#474230', '#5d5739', '#6c6444', '#8f8b5e', '#a8a47d', '#857c57', '#776e44', '#605935',
    '#384028', '#2e3826', '#293324', '#1f2b20', '#1b271c', '#1a2519', '#1b2a1e', '#2d462e',
    '#1e3a27', '#194d2b', '#1b662d', '#239037', '#39a13e', '#45b043', '#52c449', '#55a93e',
    '#1a6930', '#0b4024', '#0d3321', '#102a1c', '#193826', '#213c2d', '#243f34', '#2a4638',
    '#1b4444', '#17373a', '#1b464e', '#1b5a5f', '#27696e', '#357982', '#459198', '#3e8e8e',
    '#15383c', '#1a4348', '#1c4f55', '#2a6a72', '#347f88', '#409ca4', '#54b5bb', '#5cbfc0',
    '#213f4c', '#1f4a5c', '#205168', '#2b5e7a', '#336d8d', '#3c7da0', '#4a96b6', '#66b0cc',
    '#1a3a5c', '#1f4570', '#204c7a', '#2b5d8f', '#2d6fa2', '#3680b5', '#3f92cc', '#5aa8d4',
    '#0e1f44', '#102555', '#13316e', '#1a4088', '#1e53a2', '#2468b8', '#2e7fd4', '#4a9ee0'
];

let state = {
    paintType: 'standard',
    colorIndex: -1,
    pearlIndex: -1,
    basePrice: 0,
    multipliers: {}
};

function post(event, data) {
    return fetch('https://' + GetParentResourceName() + '/' + event, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data || {})
    });
}

function buildColorGrid(containerId, onClick) {
    const container = document.getElementById(containerId);
    container.innerHTML = '';
    GTA_COLORS.forEach((hex, i) => {
        const swatch = document.createElement('div');
        swatch.className = 'color-swatch';
        swatch.style.backgroundColor = hex;
        swatch.dataset.index = i;
        swatch.addEventListener('click', () => onClick(i, swatch, containerId));
        container.appendChild(swatch);
    });
}

function selectColor(index, swatch, containerId) {
    document.querySelectorAll('#' + containerId + ' .color-swatch').forEach(s => s.classList.remove('selected'));
    swatch.classList.add('selected');

    if (containerId === 'color-grid') {
        state.colorIndex = index;
    } else {
        state.pearlIndex = index;
    }

    updatePrice();

    post('paintPreview', {
        type: state.paintType,
        colorIndex: state.colorIndex,
        pearlIndex: state.pearlIndex
    });
}

function updatePrice() {
    const mult = state.multipliers[state.paintType] || 1.0;
    const price = Math.floor(state.basePrice * mult);
    document.getElementById('price-display').textContent = '$' + price.toLocaleString();
}

function setActiveTab(type) {
    state.paintType = type;
    state.colorIndex = -1;
    state.pearlIndex = -1;

    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelector('[data-type="' + type + '"]').classList.add('active');

    document.querySelectorAll('.color-swatch').forEach(s => s.classList.remove('selected'));

    const pearlSection = document.getElementById('pearlescent-section');
    if (type === 'pearlescent') {
        pearlSection.classList.remove('hidden');
    } else {
        pearlSection.classList.add('hidden');
    }

    if (type === 'chrome') {
        document.getElementById('color-grid').classList.add('hidden');
    } else {
        document.getElementById('color-grid').classList.remove('hidden');
    }

    updatePrice();
}

document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => setActiveTab(tab.dataset.type));
});

document.getElementById('btn-apply').addEventListener('click', () => {
    if (state.paintType === 'chrome') {
        post('paintConfirm', { type: 'chrome', colorIndex: 120, pearlIndex: -1 });
    } else if (state.colorIndex < 0) {
        return;
    } else {
        post('paintConfirm', {
            type: state.paintType,
            colorIndex: state.colorIndex,
            pearlIndex: state.pearlIndex
        });
    }
});

document.getElementById('btn-cancel').addEventListener('click', () => {
    post('paintCancel', {});
});

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        state.basePrice = data.basePrice || 500;
        state.multipliers = data.multipliers || {};
        document.getElementById('paint-panel').classList.remove('hidden');
        buildColorGrid('color-grid', selectColor);
        buildColorGrid('pearl-grid', selectColor);
        setActiveTab('standard');
    }

    if (data.action === 'close') {
        document.getElementById('paint-panel').classList.add('hidden');
        state.colorIndex = -1;
        state.pearlIndex = -1;
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        post('paintCancel', {});
    }
});
