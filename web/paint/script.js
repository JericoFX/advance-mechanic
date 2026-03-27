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

let currentMode = 'paint';

let paintState = {
    paintType: 'standard',
    colorIndex: -1,
    pearlIndex: -1,
    basePrice: 0,
    multipliers: {}
};

let wrapState = {
    zone: 'primary',
    material: 'gloss',
    primaryColor: -1,
    secondaryColor: -1,
    liveryIndex: -1,
    catalogId: -1,
    basePrice: 0,
    materials: {},
    liveries: [],
    catalog: []
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

function selectPaintColor(index, swatch, containerId) {
    document.querySelectorAll('#' + containerId + ' .color-swatch').forEach(s => s.classList.remove('selected'));
    swatch.classList.add('selected');

    if (containerId === 'color-grid') {
        paintState.colorIndex = index;
    } else {
        paintState.pearlIndex = index;
    }

    updatePaintPrice();

    post('paintPreview', {
        type: paintState.paintType,
        colorIndex: paintState.colorIndex,
        pearlIndex: paintState.pearlIndex
    });
}

function selectWrapColor(index, swatch, containerId) {
    document.querySelectorAll('#' + containerId + ' .color-swatch').forEach(s => s.classList.remove('selected'));
    swatch.classList.add('selected');

    if (wrapState.zone === 'primary') {
        wrapState.primaryColor = index;
    } else {
        wrapState.secondaryColor = index;
    }

    wrapState.catalogId = -1;
    document.querySelectorAll('.catalog-item').forEach(c => c.classList.remove('selected'));

    updateWrapPrice();

    post('wrapPreview', {
        zone: wrapState.zone,
        colorIndex: index,
        material: wrapState.material
    });
}

function updatePaintPrice() {
    const mult = paintState.multipliers[paintState.paintType] || 1.0;
    const price = Math.floor(paintState.basePrice * mult);
    document.getElementById('price-display').textContent = '$' + price.toLocaleString();
}

function updateWrapPrice() {
    const matData = wrapState.materials[wrapState.material];
    const mult = matData ? matData.priceMultiplier : 1.0;
    const price = Math.floor(wrapState.basePrice * mult);
    document.getElementById('price-display').textContent = '$' + price.toLocaleString();
}

function setActiveTab(type) {
    paintState.paintType = type;
    paintState.colorIndex = -1;
    paintState.pearlIndex = -1;

    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelector('[data-type="' + type + '"]').classList.add('active');
    document.querySelectorAll('#color-grid .color-swatch, #pearl-grid .color-swatch').forEach(s => s.classList.remove('selected'));

    const pearlSection = document.getElementById('pearlescent-section');
    pearlSection.classList.toggle('hidden', type !== 'pearlescent');
    document.getElementById('color-grid').classList.toggle('hidden', type === 'chrome');

    updatePaintPrice();
}

function setWrapZone(zone) {
    wrapState.zone = zone;
    document.querySelectorAll('.wrap-zone-btn').forEach(b => b.classList.remove('active'));
    document.querySelector('[data-zone="' + zone + '"]').classList.add('active');
    document.querySelectorAll('#wrap-color-grid .color-swatch').forEach(s => s.classList.remove('selected'));

    const currentColor = zone === 'primary' ? wrapState.primaryColor : wrapState.secondaryColor;
    if (currentColor >= 0) {
        const swatch = document.querySelector('#wrap-color-grid .color-swatch[data-index="' + currentColor + '"]');
        if (swatch) swatch.classList.add('selected');
    }
}

function setWrapMaterial(material) {
    wrapState.material = material;
    document.querySelectorAll('.material-btn').forEach(b => b.classList.remove('active'));
    document.querySelector('[data-material="' + material + '"]').classList.add('active');
    updateWrapPrice();

    if (wrapState.primaryColor >= 0 || wrapState.secondaryColor >= 0) {
        post('wrapPreview', {
            zone: wrapState.zone,
            colorIndex: wrapState.zone === 'primary' ? wrapState.primaryColor : wrapState.secondaryColor,
            material: material
        });
    }
}

function buildLiveryList(liveries) {
    const container = document.getElementById('livery-list');
    const section = document.getElementById('livery-section');
    container.innerHTML = '';

    if (!liveries || liveries.length === 0) {
        section.classList.add('hidden');
        return;
    }

    section.classList.remove('hidden');
    liveries.forEach((livery, i) => {
        const item = document.createElement('div');
        item.className = 'livery-item';
        item.textContent = livery.name || ('Livery ' + (i + 1));
        item.addEventListener('click', () => {
            document.querySelectorAll('.livery-item').forEach(l => l.classList.remove('selected'));
            item.classList.add('selected');
            wrapState.liveryIndex = livery.index;
            post('wrapLiveryPreview', { liveryIndex: livery.index });
        });
        container.appendChild(item);
    });
}

function buildCatalogList(catalog) {
    const container = document.getElementById('catalog-list');
    const section = document.getElementById('catalog-section');
    container.innerHTML = '';

    if (!catalog || catalog.length === 0) {
        section.classList.add('hidden');
        return;
    }

    section.classList.remove('hidden');
    catalog.forEach((wrap) => {
        const item = document.createElement('div');
        item.className = 'catalog-item';

        const swatch = document.createElement('div');
        swatch.className = 'catalog-swatch';
        swatch.style.backgroundColor = GTA_COLORS[wrap.primary_color] || '#333';

        const name = document.createElement('span');
        name.className = 'catalog-name';
        name.textContent = wrap.name;

        const price = document.createElement('span');
        price.className = 'catalog-price';
        price.textContent = '$' + wrap.price.toLocaleString();

        item.appendChild(swatch);
        item.appendChild(name);
        item.appendChild(price);

        item.addEventListener('click', () => {
            document.querySelectorAll('.catalog-item').forEach(c => c.classList.remove('selected'));
            item.classList.add('selected');
            wrapState.catalogId = wrap.id;
            document.getElementById('price-display').textContent = '$' + wrap.price.toLocaleString();
            post('wrapCatalogPreview', { catalogId: wrap.id });
        });

        container.appendChild(item);
    });
}

function openPaintMode(data) {
    currentMode = 'paint';
    paintState.basePrice = data.basePrice || 500;
    paintState.multipliers = data.multipliers || {};
    document.getElementById('panel-title').textContent = 'Paint Booth';
    document.getElementById('paint-section').classList.remove('hidden');
    document.getElementById('wrap-section').classList.add('hidden');
    document.getElementById('paint-panel').classList.remove('hidden');
    buildColorGrid('color-grid', selectPaintColor);
    buildColorGrid('pearl-grid', selectPaintColor);
    setActiveTab('standard');
}

function openWrapMode(data) {
    currentMode = 'wrap';
    wrapState.basePrice = data.basePrice || 2000;
    wrapState.materials = data.materials || {};
    wrapState.primaryColor = -1;
    wrapState.secondaryColor = -1;
    wrapState.liveryIndex = -1;
    wrapState.catalogId = -1;
    wrapState.zone = 'primary';
    wrapState.material = 'gloss';

    document.getElementById('panel-title').textContent = 'Vehicle Wrapping';
    document.getElementById('paint-section').classList.add('hidden');
    document.getElementById('wrap-section').classList.remove('hidden');
    document.getElementById('paint-panel').classList.remove('hidden');

    buildColorGrid('wrap-color-grid', selectWrapColor);
    buildLiveryList(data.liveries || []);
    buildCatalogList(data.catalog || []);

    document.querySelectorAll('.wrap-zone-btn').forEach(b => b.classList.remove('active'));
    document.querySelector('[data-zone="primary"]').classList.add('active');
    document.querySelectorAll('.material-btn').forEach(b => b.classList.remove('active'));
    document.querySelector('[data-material="gloss"]').classList.add('active');

    updateWrapPrice();
}

document.querySelectorAll('.tab').forEach(tab => {
    tab.addEventListener('click', () => setActiveTab(tab.dataset.type));
});

document.querySelectorAll('.wrap-zone-btn').forEach(btn => {
    btn.addEventListener('click', () => setWrapZone(btn.dataset.zone));
});

document.querySelectorAll('.material-btn').forEach(btn => {
    btn.addEventListener('click', () => setWrapMaterial(btn.dataset.material));
});

document.getElementById('btn-apply').addEventListener('click', () => {
    if (currentMode === 'paint') {
        if (paintState.paintType === 'chrome') {
            post('paintConfirm', { type: 'chrome', colorIndex: 120, pearlIndex: -1 });
        } else if (paintState.colorIndex < 0) {
            return;
        } else {
            post('paintConfirm', {
                type: paintState.paintType,
                colorIndex: paintState.colorIndex,
                pearlIndex: paintState.pearlIndex
            });
        }
    } else {
        if (wrapState.catalogId >= 0) {
            post('wrapConfirm', { catalogId: wrapState.catalogId });
        } else if (wrapState.primaryColor < 0 && wrapState.liveryIndex < 0) {
            return;
        } else {
            post('wrapConfirm', {
                primaryColor: wrapState.primaryColor,
                secondaryColor: wrapState.secondaryColor,
                material: wrapState.material,
                liveryIndex: wrapState.liveryIndex
            });
        }
    }
});

document.getElementById('btn-cancel').addEventListener('click', () => {
    post(currentMode === 'paint' ? 'paintCancel' : 'wrapCancel', {});
});

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open' && data.mode === 'paint') {
        openPaintMode(data);
    }

    if (data.action === 'open' && data.mode === 'wrap') {
        openWrapMode(data);
    }

    if (data.action === 'close') {
        document.getElementById('paint-panel').classList.add('hidden');
        paintState.colorIndex = -1;
        paintState.pearlIndex = -1;
        wrapState.primaryColor = -1;
        wrapState.secondaryColor = -1;
        wrapState.liveryIndex = -1;
        wrapState.catalogId = -1;
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        post(currentMode === 'paint' ? 'paintCancel' : 'wrapCancel', {});
    }
});
