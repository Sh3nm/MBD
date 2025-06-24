const express = require('express');
const pool = require('./db');
require('dotenv').config();
const cors = require('cors'); 

const app = express();
app.use(express.json());
app.use(cors());

const PORT = process.env.PORT || 3333; // Ndatau kenapa port 3000 kepake java.exe

app.get('/', (req, res) => {
  res.send('Server is running!');
});
app.use(express.json());

app.post('/add-flight', async (req, res) => {
  const {
    in_departure_airport,
    in_arrival_airport,
    in_departure_time,
    in_arrival_time,
    in_price,
    in_admin_id,
    in_plane_id
  } = req.body;

  try {
    const [rows] = await pool.query(
      `CALL add_flight(?, ?, ?, ?, ?, ?, ?)`,
      [
        in_departure_airport,
        in_arrival_airport,
        in_departure_time,
        in_arrival_time,
        in_price,
        in_admin_id,
        in_plane_id
      ]
    );
    res.json({ success: true, message: 'Flight added successfully' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

app.get('/search-flights', async (req, res) => {
  const {
    in_departure_city,
    in_arrival_city,
    in_departure_date,
    in_class,
    in_sort_by
  } = req.query;

  try {
    const [rows] = await pool.query(
        `CALL search_flights(?, ?, ?, ?, ?)`,
      [
        in_departure_city,
        in_arrival_city,
        in_departure_date,
        in_class,
        in_sort_by
      ]
    );
    const formatted = rows[0].map(row => ({
      ...row,
      adjusted_price: parseFloat(Number(row.adjusted_price).toFixed(2))
    }));
    res.json({
        success: true,
        count: formatted.length,
        data: formatted,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

app.get('/search-seats/:flight_id', async (req, res) => {
  const flightId = req.params.flight_id;

    try {
        const [rows] = await pool.query(
        `CALL get_available_seats(?)`,
        [flightId]
        );
        const formatted = rows[0].map(row => ({
        ...row,
        total_price: parseFloat(Number(row.total_price).toFixed(2))
        }));
        res.json({
        success: true,
        count: formatted.length,
        data: formatted,
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
});

app.post('/book-ticket', async (req, res) => {
  const {
    in_user_id,
    in_flight_id,
    in_seat_number,
    in_payment_method
  } = req.body;

  try {
    const [rows] = await pool.query(
      `CALL book_ticket(?, ?, ?, ?)`,
      [
        in_user_id,
        in_flight_id,
        in_seat_number,
        in_payment_method
      ]
    );
    const name = await pool.query(
      'SELECT name FROM user WHERE user_id = ?',
      [in_user_id]
    );
    const [ticketRows] = await pool.query(
        'SELECT * FROM view_user_tickets WHERE name = ? ORDER BY book_date DESC LIMIT 1',
        [name[0][0].name]
    )
    const formatted = {
      ...ticketRows[0],
      price: parseFloat(Number(ticketRows[0].price).toFixed(2))
    };
    res.json({
      success: true,
      message: 'Ticket ordered successfully',
      ticket: formatted
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});

app.post('/pay-ticket/:ticket_id', async (req, res) => {
    const ticketId = req.params.ticket_id;
    try {
        const [rows] = await pool.query(
        `CALL pay_ticket(?)`,
        [ticketId]
        );
        res.json({
        success: true,
        message: 'Ticket payment successful'
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
});

app.get('/print-ticket/:ticket_id', async (req, res) => {
    const ticketId = req.params.ticket_id;
    try {
        const [rows] = await pool.query(
        `CALL penerbitan_tiket(?)`,
        [ticketId]
        );
        res.json({
        success: true,
        message: 'Ticket print successful'
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
});

app.patch('/cancel-ticket/:ticket_id', async (req, res) => {
    const ticketId = req.params.ticket_id;
    try {
        const [rows] = await pool.query(
        `CALL cancel_ticket(?)`,
        [ticketId]
        );
        res.json({
        success: true,
        message: 'Cancel ticket successful'
        });
    } catch (err) {
        console.error(err);
        res.status(500).json({ success: false, error: 'Internal server error' });
    }
});
app.get('/get-tickets/:user_id', async (req, res) => {
  const userId = req.params.user_id;
  const ticketId = req.query.ticket_id;

  try {
    const [[{ name }]] = await pool.query(
      'SELECT name FROM user WHERE user_id = ?',
      [userId]
    );

    let query = `SELECT * FROM view_user_tickets WHERE name = ?`;
    let params = [name];

    if (ticketId) {
      query += ` AND ticket_id = ?`;
      params.push(ticketId);
    }

    query += ` ORDER BY book_date DESC`;

    const [rows] = await pool.query(query, params);

    const formatted = rows.map(row => ({
      ...row,
      price: parseFloat(Number(row.price).toFixed(2))
    }));

    res.json({
      success: true,
      count: formatted.length,
      data: formatted
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: 'Internal server error' });
  }
});



app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
