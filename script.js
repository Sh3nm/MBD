const API_BASE_URL = 'http://localhost:3333'; 

let currentUser = { id: 1, name: 'Budi Bijaksana', email: 'budibijaksana@gmail.com' }; 
let currentAdmin = { id: 1, name: 'admin', email: 'admin1@gmail.com' }; 



function showSection(id) {
    document.querySelectorAll('section').forEach(section => {
        section.style.display = 'none';
    });
    document.getElementById(id).style.display = 'block';

    if (id === 'my-tickets' && currentUser) {
        fetchMyTickets();
    }
}

function updateAuthUI() {
    const loginRegisterSection = document.getElementById('login-register');
    const myTicketsBtn = document.querySelector('button[onclick="showSection(\'my-tickets\')"]');
    const bookTicketBtn = document.querySelector('button[onclick="showSection(\'book-ticket\')"]');
    const adminFlightManagementBtn = document.querySelector('button[onclick="showSection(\'admin-flight-management\')"]');
    const logoutBtn = document.getElementById('logoutBtn');

    if (currentUser || currentAdmin) {
        loginRegisterSection.style.display = 'none'; 
        logoutBtn.style.display = 'inline-block';
        if (currentUser) { 
            myTicketsBtn.style.display = 'inline-block';
            bookTicketBtn.style.display = 'inline-block';
            adminFlightManagementBtn.style.display = 'none'; 
        } else if (currentAdmin) { 
            myTicketsBtn.style.display = 'none';
            bookTicketBtn.style.display = 'none';
            adminFlightManagementBtn.style.display = 'inline-block';
        }
    } else {
        loginRegisterSection.style.display = 'block'
        logoutBtn.style.display = 'none';
        myTicketsBtn.style.display = 'none';
        bookTicketBtn.style.display = 'none';
        adminFlightManagementBtn.style.display = 'none';
    }
    showSection('home'); 
}


function logoutUser() {
    currentUser = null;
    currentAdmin = null;
    
    localStorage.removeItem('userToken');
    localStorage.removeItem('adminToken');
    alert('Anda telah logout.');
    updateAuthUI();
}


document.getElementById('loginForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('loginEmail').value;
    const password = document.getElementById('loginPassword').value;
    const authMessage = document.getElementById('authMessage');

    console.log('Attempting SIMULATED login with:', { email, password });

    if (email === 'budibijaksana@gmail.com' && password === 'budibijak09') { 
        currentUser = { id: 1, name: 'Budi Bijaksana', email: email };
        currentAdmin = null; 
        authMessage.textContent = 'Login pengguna berhasil!';
        authMessage.className = 'message success';
    } else if (email === 'admin1@gmail.com' && password === 'password') { 
        currentAdmin = { id: 1, name: 'admin', email: email };
        currentUser = null; 
        authMessage.textContent = 'Login admin berhasil!';
        authMessage.className = 'message success';
    } else {
        authMessage.textContent = 'Email atau password salah. (Simulasi)';
        authMessage.className = 'message error';
        currentUser = null;
        currentAdmin = null;
    }
    updateAuthUI();
});

document.getElementById('registerForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const name = document.getElementById('registerName').value;
    const email = document.getElementById('registerEmail').value;
    const phone = document.getElementById('registerPhone').value;
    const password = document.getElementById('registerPassword').value;
    const authMessage = document.getElementById('authMessage');

    console.log('Attempting SIMULATED registration with:', { name, email, phone, password });
    authMessage.textContent = 'Registrasi berhasil! Silakan login. (Simulasi)';
    authMessage.className = 'message success';
});


document.getElementById('searchFlightForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const departureCity = document.getElementById('departureCity').value;
    const arrivalCity = document.getElementById('arrivalCity').value;
    const departureDate = document.getElementById('departureDate').value;
    const flightClass = document.getElementById('flightClass').value;
    const sortBy = document.getElementById('sortBy').value;
    const flightResultsTableBody = document.querySelector('#flightResultsTable tbody');
    const searchFlightMessage = document.getElementById('searchFlightMessage');

    flightResultsTableBody.innerHTML = ''; 
    searchFlightMessage.textContent = 'Mencari penerbangan...';
    searchFlightMessage.className = 'message info';

    const params = new URLSearchParams({
        in_departure_city: departureCity,
        in_arrival_city: arrivalCity,
        in_departure_date: departureDate,
        in_class: flightClass,
        in_sort_by: sortBy
    }).toString();

    try {
        const response = await fetch(`${API_BASE_URL}/search-flights?${params}`);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const result = await response.json();

        if (result.success && result.data.length > 0) {
            result.data.forEach(flight => {
                const row = flightResultsTableBody.insertRow();
                row.insertCell().textContent = flight.flight_id;
                row.insertCell().textContent = flight.departure_time;
                row.insertCell().textContent = flight.arrival_time;
                row.insertCell().textContent = flight.departure_iata;
                row.insertCell().textContent = flight.arrival_iata;
                row.insertCell().textContent = flight.departure_city;
                row.insertCell().textContent = flight.arrival_city;
                row.insertCell().textContent = flight.class_name;
                row.insertCell().textContent = parseFloat(flight.adjusted_price).toLocaleString('id-ID', { style: 'currency', currency: 'IDR' });
                row.insertCell().textContent = flight.duration_minutes;
                const actionCell = row.insertCell();
                const bookButton = document.createElement('button');
                bookButton.textContent = 'Pesan Kursi';
                bookButton.onclick = () => showAvailableSeats(flight.flight_id);
                actionCell.appendChild(bookButton);
            });
            searchFlightMessage.textContent = `Ditemukan ${result.count} penerbangan.`;
            searchFlightMessage.className = 'message success';
        } else {
            searchFlightMessage.textContent = 'Tidak ada penerbangan yang ditemukan.';
            searchFlightMessage.className = 'message info';
        }

    } catch (error) {
        console.error('Error searching flights:', error);
        searchFlightMessage.textContent = 'Terjadi kesalahan saat mencari penerbangan.';
        searchFlightMessage.className = 'message error';
    }
});


async function showAvailableSeats(flightId) {
    if (!currentUser) {
        alert('Anda harus login untuk memesan tiket.');
        showSection('login-register');
        return;
    }
    showSection('book-ticket');
    document.getElementById('availableSeatsSection').style.display = 'block';
    document.getElementById('currentFlightId').textContent = flightId;
    const availableSeatsTableBody = document.querySelector('#availableSeatsTable tbody');
    const availableSeatsMessage = document.getElementById('availableSeatsMessage');
    availableSeatsTableBody.innerHTML = '';
    availableSeatsMessage.textContent = 'Mencari kursi tersedia...';
    availableSeatsMessage.className = 'message info';

    try {
        const response = await fetch(`${API_BASE_URL}/search-seats/${flightId}`);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const result = await response.json();

        if (result.success && result.data.length > 0) {
            result.data.forEach(seat => {
                const row = availableSeatsTableBody.insertRow();
                row.insertCell().textContent = seat.seat_number;
                row.insertCell().textContent = seat.class_name;
                row.insertCell().textContent = parseFloat(seat.total_price).toLocaleString('id-ID', { style: 'currency', currency: 'IDR' });
                const actionCell = row.insertCell();
                const bookBtn = document.createElement('button');
                bookBtn.textContent = 'Pesan Kursi Ini';
                bookBtn.onclick = () => {
                    document.getElementById('bookFlightId').value = flightId;
                    document.getElementById('bookSeatNumber').value = seat.seat_number;
                    // Optionally pre-fill class or price here if needed for display
                    alert(`Anda akan memesan kursi ${seat.seat_number} untuk penerbangan ID ${flightId}. Silakan lengkapi metode pembayaran.`);
                };
                actionCell.appendChild(bookBtn);
            });
            availableSeatsMessage.textContent = `Ditemukan ${result.count} kursi tersedia.`;
            availableSeatsMessage.className = 'message success';
        } else {
            availableSeatsMessage.textContent = 'Tidak ada kursi tersedia untuk penerbangan ini atau kelas yang dipilih.';
            availableSeatsMessage.className = 'message info';
        }

    } catch (error) {
        console.error('Error fetching available seats:', error);
        availableSeatsMessage.textContent = 'Terjadi kesalahan saat mencari kursi tersedia.';
        availableSeatsMessage.className = 'message error';
    }
}



document.getElementById('bookTicketForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!currentUser) {
        alert('Anda harus login untuk memesan tiket.');
        showSection('login-register');
        return;
    }
    const flightId = document.getElementById('bookFlightId').value;
    const seatNumber = document.getElementById('bookSeatNumber').value;
    const paymentMethod = document.getElementById('bookPaymentMethod').value;
    const bookTicketMessage = document.getElementById('bookTicketMessage');

    bookTicketMessage.textContent = 'Memproses pemesanan...';
    bookTicketMessage.className = 'message info';

    if (!flightId || !seatNumber || !paymentMethod) {
        bookTicketMessage.textContent = 'Harap lengkapi semua bidang untuk pemesanan tiket.';
        bookTicketMessage.className = 'message error';
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/book-ticket`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                
            },
            body: JSON.stringify({
                in_user_id: currentUser.id, 
                in_flight_id: flightId,
                in_seat_number: seatNumber,
                in_payment_method: paymentMethod
            })
        });
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(`HTTP error! status: ${response.status}, message: ${errorData.error || 'Unknown error'}`);
        }
        const result = await response.json();

        if (result.success) {
            bookTicketMessage.textContent = `Tiket berhasil dipesan! Status: Pending pembayaran.`;
            bookTicketMessage.className = 'message success';
            
            document.getElementById('bookFlightId').value = '';
            document.getElementById('bookSeatNumber').value = '';
            document.getElementById('bookPaymentMethod').value = '';
        } else {
             bookTicketMessage.textContent = result.error || 'Gagal memesan tiket.';
             bookTicketMessage.className = 'message error';
        }

    } catch (error) {
        console.error('Error booking ticket:', error);
        bookTicketMessage.textContent = `Terjadi kesalahan saat memesan tiket: ${error.message}. Kursi mungkin sudah terisi atau data tidak valid.`;
        bookTicketMessage.className = 'message error';
    }
});


async function payTicket(ticketId) {
    if (!currentUser) {
        alert('Anda harus login untuk membayar tiket.');
        showSection('login-register');
        return;
    }
    if (!confirm(`Anda yakin ingin melakukan pembayaran untuk tiket ID ${ticketId}?`)) {
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/pay-ticket/${ticketId}`, {
            method: 'POST',
            
        });
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(`HTTP error! status: ${response.status}, message: ${errorData.error || 'Unknown error'}`);
        }
        const result = await response.json();

        if (result.success) {
            alert(`Pembayaran untuk tiket ID ${ticketId} berhasil!`);
            fetchMyTickets(); 
        } else {
            alert(`Gagal membayar tiket ID ${ticketId}: ${result.error || 'Unknown error'}`);
        }
    } catch (error) {
        console.error('Error paying ticket:', error);
        alert(`Terjadi kesalahan saat membayar tiket ID ${ticketId}: ${error.message}`);
    }
}


async function printTicket(ticketId) {
    if (!currentUser) {
        alert('Anda harus login untuk menerbitkan tiket.');
        showSection('login-register');
        return;
    }
    if (!confirm(`Anda ingin menerbitkan tiket ID ${ticketId}? Pastikan sudah dibayar.`)) {
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/print-ticket/${ticketId}`, {
            method: 'GET', 
        });
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(`HTTP error! status: ${response.status}, message: ${errorData.error || 'Unknown error'}`);
        }
        const result = await response.json();

        if (result.success) {
            alert(`Tiket ID ${ticketId} berhasil diterbitkan!`);
            fetchMyTickets(); 
        } else {
            alert(`Gagal menerbitkan tiket ID ${ticketId}: ${result.error || 'Status pembayaran belum "paid".'}`);
        }
    } catch (error) {
        console.error('Error printing ticket:', error);
        alert(`Terjadi kesalahan saat menerbitkan tiket ID ${ticketId}: ${error.message}`);
    }
}



async function cancelTicket(ticketId) {
    if (!currentUser) {
        alert('Anda harus login untuk membatalkan tiket.');
        showSection('login-register');
        return;
    }
    if (!confirm(`Anda yakin ingin membatalkan tiket ID ${ticketId}?`)) {
        return;
    }

    try {
        const response = await fetch(`${API_BASE_URL}/cancel-ticket/${ticketId}`, {
            method: 'PATCH', 
        });
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(`HTTP error! status: ${response.status}, message: ${errorData.error || 'Unknown error'}`);
        }
        const result = await response.json();

        if (result.success) {
            alert(`Tiket ID ${ticketId} berhasil dibatalkan.`);
            fetchMyTickets(); 
        } else {
            alert(`Gagal membatalkan tiket ID ${ticketId}: ${result.error || 'Unknown error'}`);
        }
    } catch (error) {
        console.error('Error canceling ticket:', error);
        alert(`Terjadi kesalahan saat membatalkan tiket ID ${ticketId}: ${error.message}`);
    }
}



async function fetchMyTickets() {
    if (!currentUser) {
        document.getElementById('myTicketsMessage').textContent = 'Silakan login untuk melihat tiket Anda.';
        document.getElementById('myTicketsMessage').className = 'message info';
        document.querySelector('#myTicketsTable tbody').innerHTML = '';
        return;
    }

    const myTicketsTableBody = document.querySelector('#myTicketsTable tbody');
    const myTicketsMessage = document.getElementById('myTicketsMessage');
    myTicketsTableBody.innerHTML = '';
    myTicketsMessage.textContent = 'Mengambil tiket Anda...';
    myTicketsMessage.className = 'message info';

    try {
        
        const response = await fetch(`${API_BASE_URL}/get-tickets/${currentUser.id}`);
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        const result = await response.json();

        if (result.success && result.data.length > 0) {
            result.data.forEach(ticket => {
                const row = myTicketsTableBody.insertRow();
                row.insertCell().textContent = ticket.ticket_id;
                row.insertCell().textContent = ticket.ticket_status;
                row.insertCell().textContent = ticket.book_date;
                row.insertCell().textContent = ticket.seat_number;
                row.insertCell().textContent = ticket.class_name;
                row.insertCell().textContent = ticket.name;
                row.insertCell().textContent = ticket.departure_time;
                row.insertCell().textContent = ticket.arrival_time;
                row.insertCell().textContent = ticket.departure_iata;
                row.insertCell().textContent = ticket.arrival_iata;
                row.insertCell().textContent = parseFloat(ticket.price).toLocaleString('id-ID', { style: 'currency', currency: 'IDR' });

                const actionCell = row.insertCell();
                if (ticket.ticket_status === 'pending') {
                    const payBtn = document.createElement('button');
                    payBtn.textContent = 'Bayar';
                    payBtn.className = 'action-button';
                    payBtn.onclick = () => payTicket(ticket.ticket_id);
                    actionCell.appendChild(payBtn);
                }
                if (ticket.ticket_status === 'booked') { 
                    const printBtn = document.createElement('button');
                    printBtn.textContent = 'Terbitkan';
                    printBtn.className = 'action-button';
                    printBtn.onclick = () => printTicket(ticket.ticket_id);
                    actionCell.appendChild(printBtn);
                }
                const cancelBtn = document.createElement('button');
                cancelBtn.textContent = 'Batalkan';
                cancelBtn.className = 'action-button';
                cancelBtn.onclick = () => cancelTicket(ticket.ticket_id);
                actionCell.appendChild(cancelBtn);
            });
            myTicketsMessage.textContent = `Ditemukan ${result.count} tiket Anda.`;
            myTicketsMessage.className = 'message success';
        } else {
            myTicketsMessage.textContent = 'Anda belum memiliki tiket yang dipesan.';
            myTicketsMessage.className = 'message info';
        }

    } catch (error) {
        console.error('Error fetching my tickets:', error);
        myTicketsMessage.textContent = 'Terjadi kesalahan saat mengambil tiket Anda.';
        myTicketsMessage.className = 'message error';
    }
}


document.getElementById('addFlightForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    if (!currentAdmin) {
        alert('Anda harus login sebagai admin untuk menambahkan penerbangan.');
        showSection('login-register');
        return;
    }

    const departureAirport = document.getElementById('addDepartureAirport').value;
    const arrivalAirport = document.getElementById('addArrivalAirport').value;
    const departureTime = document.getElementById('addDepartureTime').value;
    const arrivalTime = document.getElementById('addArrivalTime').value;
    const price = document.getElementById('addPrice').value;
    const adminId = document.getElementById('addAdminId').value;
    const planeId = document.getElementById('addPlaneId').value;
    const addFlightMessage = document.getElementById('addFlightMessage');

    addFlightMessage.textContent = 'Menambahkan penerbangan...';
    addFlightMessage.className = 'message info';

    try {
        const response = await fetch(`${API_BASE_URL}/add-flight`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                
            },
            body: JSON.stringify({
                in_departure_airport: departureAirport,
                in_arrival_airport: arrivalAirport,
                in_departure_time: departureTime,
                in_arrival_time: arrivalTime,
                in_price: price,
                in_admin_id: adminId, 
                in_plane_id: planeId
            })
        });
        if (!response.ok) {
            const errorData = await response.json();
            throw new Error(`HTTP error! status: ${response.status}, message: ${errorData.error || 'Unknown error'}`);
        }
        const result = await response.json();

        if (result.success) {
            addFlightMessage.textContent = 'Penerbangan berhasil ditambahkan!';
            addFlightMessage.className = 'message success';
            document.getElementById('addFlightForm').reset(); 
        } else {
            addFlightMessage.textContent = result.error || 'Gagal menambahkan penerbangan.';
            addFlightMessage.className = 'message error';
        }
    } catch (error) {
        console.error('Error adding flight:', error);
        addFlightMessage.textContent = `Terjadi kesalahan saat menambahkan penerbangan: ${error.message}`;
        addFlightMessage.className = 'message error';
    }
});



document.addEventListener('DOMContentLoaded', updateAuthUI);