let isOpen = false;
let items = [];
let selectedItem = null;
let maxAmount = 1;

const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'phils-garbage';

// NUI Message Handler
window.addEventListener('message', function(event) {
    const data = event.data;
    
    if (data.action === 'openTrash') {
        openTrashUI(data.items);
    }
    
    if (data.action === 'closeTrash') {
        closeTrashUI();
    }
});

// Open Trash UI
function openTrashUI(inventoryItems) {
    isOpen = true;
    items = inventoryItems || [];
    
    document.getElementById('trash-container').classList.remove('hidden');
    renderItems();
}

// Close Trash UI
function closeTrashUI() {
    isOpen = false;
    items = [];
    selectedItem = null;
    
    document.getElementById('trash-container').classList.add('hidden');
    document.getElementById('quantity-modal').classList.add('hidden');
    
    fetch(`https://${resourceName}/closeUI`, {
        method: 'POST',
        body: JSON.stringify({})
    });
}

// Render Items
function renderItems() {
    const itemsList = document.getElementById('items-list');
    const emptyState = document.getElementById('empty-state');
    const itemCount = document.getElementById('item-count');
    
    // Filter only items (not weapons, etc.)
    const filteredItems = items.filter(item => item.type === 'item' && item.amount > 0);
    
    if (filteredItems.length === 0) {
        itemsList.classList.add('hidden');
        emptyState.classList.remove('hidden');
        itemCount.textContent = '0 items';
        return;
    }
    
    emptyState.classList.add('hidden');
    itemsList.classList.remove('hidden');
    itemCount.textContent = filteredItems.length + ' item' + (filteredItems.length !== 1 ? 's' : '');
    
    let html = '';
    filteredItems.forEach((item, index) => {
        html += `
            <div class="item-card" data-index="${index}" data-name="${item.name}" data-amount="${item.amount}" data-label="${item.label}" data-image="${item.image}">
                <span class="item-amount">${item.amount}</span>
                <img src="nui://rsg-inventory/html/images/${item.image}" alt="${item.label}" onerror="this.src='nui://rsg-inventory/html/images/placeholder.png'">
                <span class="item-name">${item.label}</span>
            </div>
        `;
    });
    
    itemsList.innerHTML = html;
    
    // Bind click events
    document.querySelectorAll('.item-card').forEach(card => {
        card.addEventListener('click', function() {
            selectItem(this);
        });
    });
}

// Select Item
function selectItem(cardElement) {
    selectedItem = {
        name: cardElement.dataset.name,
        label: cardElement.dataset.label,
        amount: parseInt(cardElement.dataset.amount),
        image: cardElement.dataset.image
    };
    
    maxAmount = selectedItem.amount;
    
    // Update modal
    document.getElementById('selected-item-img').src = `nui://rsg-inventory/html/images/${selectedItem.image}`;
    document.getElementById('selected-item-name').textContent = selectedItem.label;
    document.getElementById('selected-item-amount').textContent = selectedItem.amount;
    document.getElementById('quantity-input').value = 1;
    document.getElementById('quantity-input').max = maxAmount;
    
    // Show modal
    document.getElementById('quantity-modal').classList.remove('hidden');
}

// Close Modal
function closeModal() {
    document.getElementById('quantity-modal').classList.add('hidden');
    selectedItem = null;
}

// Update Quantity
function updateQuantity(delta) {
    const input = document.getElementById('quantity-input');
    let value = parseInt(input.value) || 1;
    value += delta;
    value = Math.max(1, Math.min(maxAmount, value));
    input.value = value;
}

// Set Quantity
function setQuantity(qty) {
    const input = document.getElementById('quantity-input');
    if (qty === 'all') {
        input.value = maxAmount;
    } else {
        input.value = Math.min(parseInt(qty), maxAmount);
    }
}

// Confirm Dispose
function confirmDispose() {
    if (!selectedItem) return;
    
    const quantity = parseInt(document.getElementById('quantity-input').value) || 1;
    
    if (quantity < 1 || quantity > maxAmount) {
        return;
    }
    
    // Send to client
    fetch(`https://${resourceName}/disposeItem`, {
        method: 'POST',
        body: JSON.stringify({
            item: selectedItem.name,
            label: selectedItem.label,
            quantity: quantity
        })
    });
    
    // Close modal and refresh
    closeModal();
    closeTrashUI();
}

// Event Listeners
document.getElementById('close-btn').addEventListener('click', closeTrashUI);
document.getElementById('cancel-dispose').addEventListener('click', closeModal);
document.getElementById('confirm-dispose').addEventListener('click', confirmDispose);
document.getElementById('qty-decrease').addEventListener('click', () => updateQuantity(-1));
document.getElementById('qty-increase').addEventListener('click', () => updateQuantity(1));

// Quick Quantity Buttons
document.querySelectorAll('.quick-qty').forEach(btn => {
    btn.addEventListener('click', function() {
        setQuantity(this.dataset.qty);
    });
});

// Input validation
document.getElementById('quantity-input').addEventListener('input', function() {
    let value = parseInt(this.value) || 1;
    value = Math.max(1, Math.min(maxAmount, value));
    this.value = value;
});

// ESC Key Handler
document.addEventListener('keydown', function(e) {
    if (!isOpen) return;
    
    if (e.key === 'Escape') {
        const modal = document.getElementById('quantity-modal');
        if (!modal.classList.contains('hidden')) {
            closeModal();
        } else {
            closeTrashUI();
        }
    }
});

// Prevent right-click
document.addEventListener('contextmenu', e => e.preventDefault());