-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Host: 127.0.0.1
-- Waktu pembuatan: 21 Jun 2025 pada 12.48
-- Versi server: 10.4.32-MariaDB
-- Versi PHP: 8.2.12

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `sistem_pemesanan_tiket_pesawat`
--

DELIMITER $$
--
-- Prosedur
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `add_flight` (IN `in_departure_airport` CHAR(3), IN `in_arrival_airport` CHAR(3), IN `in_departure_time` DATETIME, IN `in_arrival_time` DATETIME, IN `in_price` DECIMAL(10,2), IN `in_admin_id` INT, IN `in_plane_id` INT)   BEGIN
    DECLARE var_flight_id INT;
    DECLARE var_departure_airport_id INT;
    DECLARE var_arrival_airport_id INT;

    SELECT airport_id INTO var_departure_airport_id
    FROM airport WHERE iata_code = in_departure_airport;

    SELECT airport_id INTO var_arrival_airport_id
    FROM airport WHERE iata_code = in_arrival_airport;

    INSERT INTO flight (departure_time, arrival_time, price, Admin_admin_id, Plane_plane_id)
    VALUES (in_departure_time, in_arrival_time, in_price, in_admin_id, in_plane_id);

    SET var_flight_id = LAST_INSERT_ID();

    INSERT INTO flight_airport (Flight_flight_id, Airport_airport_id, direction)
    VALUES (var_flight_id, var_departure_airport_id, 'departure');

    INSERT INTO flight_airport (Flight_flight_id, Airport_airport_id, direction)
    VALUES (var_flight_id, var_arrival_airport_id, 'arrival');
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `book_ticket` (IN `in_user_id` INT, IN `in_flight_id` INT, IN `in_seat_number` VARCHAR(3), IN `in_payment_method` VARCHAR(10))   BEGIN
    DECLARE seat_taken INT;
    DECLARE base_price DECIMAL(10,2);
    DECLARE multiplier DECIMAL(3,2);
    DECLARE total_price DECIMAL(10,2);
    DECLARE new_ticket_id INT;
    DECLARE new_payment_id INT;
    DECLARE plane_id INT;
    DECLARE class_id INT;

    SELECT Plane_Plane_id INTO plane_id
    FROM flight
    WHERE flight_id = in_flight_id;

    SELECT Class_class_id INTO class_id
    FROM seat
    WHERE seat_number = in_seat_number
      AND Plane_Plane_id = plane_id
    LIMIT 1;

    IF class_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid seat for this plane.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM seatFlight
        WHERE seat_number = in_seat_number
          AND Plane_Plane_id = plane_id
          AND Flight_flight_id = in_flight_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Seat already taken for this flight.';
    END IF;

    START TRANSACTION;

    INSERT INTO seatFlight (seat_number, Plane_Plane_id, Flight_flight_id)
    VALUES (in_seat_number, plane_id, in_flight_id);

    SELECT price INTO base_price
    FROM flight
    WHERE flight_id = in_flight_id;

    SELECT price_multiplier INTO multiplier
    FROM class
    WHERE class.class_id = class_id;

    SET total_price = base_price * multiplier;

    INSERT INTO ticket (
        book_date, seat_number, status, User_user_id, 
        Class_class_id, Flight_flight_id
    ) VALUES (
        NOW(), in_seat_number, 'pending', in_user_id, 
        class_id, in_flight_id
    );

    SET new_ticket_id = LAST_INSERT_ID();

    INSERT INTO payment (
        payment_date, amount, payment_method, payment_status, Ticket_ticket_id
    ) VALUES (
        NOW(), total_price, in_payment_method, 'pending', new_ticket_id
    );

    COMMIT;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `cancel_ticket` (IN `in_ticket_id` INT)   BEGIN
    DECLARE v_user_id INT;
    DECLARE v_seat_number VARCHAR(3);
    DECLARE v_flight_id INT;
    DECLARE v_plane_id INT;

    SELECT 
        User_user_id, 
        seat_number, 
        Flight_flight_id 
    INTO 
        v_user_id, 
        v_seat_number, 
        v_flight_id
    FROM ticket
    WHERE ticket_id = in_ticket_id;

    SELECT Plane_Plane_id INTO v_plane_id
    FROM flight
    WHERE flight_id = v_flight_id;

    UPDATE ticket
    SET status = 'cancelled'
    WHERE ticket_id = in_ticket_id;

    UPDATE payment
    SET payment_status = 'failed'
    WHERE Ticket_ticket_id = in_ticket_id;

    DELETE FROM seatFlight
    WHERE seat_number = v_seat_number
      AND Plane_Plane_id = v_plane_id
      AND Flight_flight_id = v_flight_id;

    INSERT INTO activitylog (
        activity_type, activity_time, description, User_user_id
    ) VALUES (
        'Cancel Ticket',
        NOW(),
        CONCAT('Membatalkan tiket ', in_ticket_id),
        v_user_id
    );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_available_seats` (IN `in_flight_id` INT)   BEGIN
    SELECT *
    FROM view_available_seats_only
    WHERE flight_id = in_flight_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_user_tickets` (IN `in_user_id` INT)   BEGIN
    SELECT 
        ticket_id,
        ticket_status,
        book_date,
        seat_number,
        class_name,
        name,
        departure_time,
        arrival_time,
        departure_iata,
        arrival_iata,
        price
    FROM view_user_tickets
    WHERE User_user_id = in_user_id;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `pay_ticket` (IN `in_ticket_id` INT)   BEGIN
    DECLARE v_payment_id INT;
    DECLARE v_user_id INT;

    SELECT payment_id INTO v_payment_id
    FROM payment
    WHERE Ticket_ticket_id = in_ticket_id;

    IF v_payment_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Payment for this ticket not found.';
    END IF;

    UPDATE payment
    SET payment_status = 'paid'
    WHERE payment_id = v_payment_id;

    INSERT INTO paymenthistory (status, change_time, Payment_payment_id)
    VALUES ('paid', NOW(), v_payment_id);

    UPDATE ticket
    SET status = 'booked'
    WHERE ticket_id = in_ticket_id;

    SELECT User_user_id INTO v_user_id
    FROM ticket
    WHERE ticket_id = in_ticket_id;

    INSERT INTO activitylog (activity_type, activity_time, description, User_user_id)
    VALUES (
        'Pembayaran Tiket',
        NOW(),
        CONCAT('Tiket dengan ID ', in_ticket_id, ' telah dibayar dan diterbitkan.'),
        v_user_id
    );
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `penerbitan_tiket` (IN `in_ticket_id` INT)   BEGIN
    DECLARE v_payment_status ENUM('paid', 'pending', 'failed');
    DECLARE v_user_id INT;

    SELECT payment_status INTO v_payment_status
    FROM payment
    WHERE Ticket_ticket_id = in_ticket_id;

    IF v_payment_status = 'paid' THEN
        SELECT User_user_id INTO v_user_id
        FROM ticket
        WHERE ticket_id = in_ticket_id;

        INSERT INTO activitylog (activity_type, activity_time, description, User_user_id)
        VALUES (
            'Penerbitan Tiket',
            NOW(),
            CONCAT('Tiket dengan ID ', in_ticket_id, ' berhasil diterbitkan.'),
            v_user_id
        );
    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Tiket tidak bisa diterbitkan karena status pembayaran belum "paid".';
    END IF;
END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `search_flights` (IN `in_departure_city` VARCHAR(100), IN `in_arrival_city` VARCHAR(100), IN `in_departure_date` DATE, IN `in_class` VARCHAR(20), IN `in_sort_by` VARCHAR(20))   BEGIN
    SELECT *
    FROM flight_details
    WHERE class_name = in_class
      AND (in_departure_city IS NULL OR departure_city = in_departure_city)
      AND (in_arrival_city IS NULL OR arrival_city = in_arrival_city)
      AND (in_departure_date IS NULL OR DATE(departure_time) = in_departure_date)
      AND count_available_seats(flight_id, in_class)
    ORDER BY
      CASE 
        WHEN in_sort_by = 'cheapest' THEN adjusted_price
        WHEN in_sort_by = 'shortest' THEN duration_minutes
        ELSE NULL
      END;
END$$

--
-- Fungsi
--
CREATE DEFINER=`root`@`localhost` FUNCTION `count_available_seats` (`in_flight_id` INT, `in_class_name` VARCHAR(20)) RETURNS INT(11) DETERMINISTIC READS SQL DATA BEGIN
    DECLARE available_count INT;

    SELECT COUNT(*) INTO available_count
    FROM view_available_seats_only
    WHERE flight_id = in_flight_id
      AND (in_class_name IS NULL OR class_name = in_class_name);

    RETURN available_count;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Struktur dari tabel `activitylog`
--

CREATE TABLE `activitylog` (
  `log_id` int(11) NOT NULL,
  `activity_type` varchar(50) NOT NULL,
  `activity_time` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `description` text NOT NULL,
  `User_user_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `activitylog`
--

INSERT INTO `activitylog` (`log_id`, `activity_type`, `activity_time`, `description`, `User_user_id`) VALUES
(1, 'Booking', '2025-06-14 12:21:26', 'User memesan tiket flight 2, seat 3A', 1),
(2, 'Booking', '2025-06-14 12:23:44', 'User memesan tiket flight 2, seat 4A', 1),
(3, 'Booking', '2025-06-14 12:58:10', 'User memesan tiket flight 2, seat 1F', 1),
(4, 'Booking', '2025-06-14 12:59:07', 'User memesan tiket flight 2, seat 4F', 1),
(6, 'Penerbitan Tiket', '2025-06-14 14:05:11', 'Tiket dengan ID 4 berhasil diterbitkan.', 1),
(7, 'Cancel Ticket', '2025-06-14 14:31:32', 'Membatalkan tiket 1', 1),
(8, 'Booking', '2025-06-21 09:55:28', 'User memesan tiket flight 4, seat 1A', 1),
(9, 'Booking', '2025-06-21 10:03:21', 'User memesan tiket flight 5, seat 1A', 1),
(10, 'Booking', '2025-06-21 10:05:20', 'User memesan tiket flight 5, seat 2A', 1),
(11, 'Booking', '2025-06-21 10:05:38', 'User memesan tiket flight 5, seat 3A', 1),
(12, 'Booking', '2025-06-21 10:05:49', 'User memesan tiket flight 5, seat 4A', 1),
(13, 'Booking', '2025-06-21 10:06:22', 'User memesan tiket flight 5, seat 5A', 1),
(14, 'Booking', '2025-06-21 10:06:50', 'User memesan tiket flight 3, seat 1A', 1),
(15, 'Booking', '2025-06-21 10:08:34', 'User memesan tiket flight 3, seat 2A', 1),
(16, 'Booking', '2025-06-21 10:10:28', 'User memesan tiket flight 3, seat 3A', 1),
(17, 'Booking', '2025-06-21 10:13:12', 'User memesan tiket flight 3, seat 4A', 1),
(18, 'Pembayaran Tiket', '2025-06-21 10:21:20', 'Tiket dengan ID 10 telah dibayar dan diterbitkan.', 1),
(19, 'Penerbitan Tiket', '2025-06-21 10:29:02', 'Tiket dengan ID 10 berhasil diterbitkan.', 1),
(20, 'Cancel Ticket', '2025-06-21 10:30:31', 'Membatalkan tiket 10', 1);

-- --------------------------------------------------------

--
-- Struktur dari tabel `admin`
--

CREATE TABLE `admin` (
  `admin_id` int(11) NOT NULL,
  `Name` varchar(100) NOT NULL,
  `Email` varchar(100) NOT NULL,
  `Password` varchar(100) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `admin`
--

INSERT INTO `admin` (`admin_id`, `Name`, `Email`, `Password`) VALUES
(1, 'admin', 'admin1@gmail.com', 'password');

-- --------------------------------------------------------

--
-- Struktur dari tabel `airport`
--

CREATE TABLE `airport` (
  `Airport_id` int(11) NOT NULL,
  `Airport_name` varchar(100) NOT NULL,
  `City` varchar(100) NOT NULL,
  `Country` varchar(100) NOT NULL,
  `iata_code` char(3) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `airport`
--

INSERT INTO `airport` (`Airport_id`, `Airport_name`, `City`, `Country`, `iata_code`) VALUES
(1, 'Soekarno-Hatta International Airport', 'Jakarta', 'Indonesia', 'CGK'),
(2, 'Juanda International Airport', 'Surabaya', 'Indonesia', 'SUB'),
(3, 'Singapore Changi Airport', 'Singapore', 'Singapore', 'SIN'),
(4, 'Jenderal Ahmad Yani Airport', 'Semarang', 'Indonesia', 'SRG'),
(5, 'I Gusti Ngurah Rai International Airport', 'Denpasar', 'Indonesia', 'DPS');

-- --------------------------------------------------------

--
-- Struktur dari tabel `class`
--

CREATE TABLE `class` (
  `class_id` int(11) NOT NULL,
  `class_name` varchar(20) NOT NULL,
  `price_multiplier` decimal(3,2) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `class`
--

INSERT INTO `class` (`class_id`, `class_name`, `price_multiplier`) VALUES
(0, 'Economy', 1.00),
(1, 'Premium Economy', 1.25),
(2, 'Business', 1.50),
(3, 'First Class', 2.00);

-- --------------------------------------------------------

--
-- Struktur dari tabel `flight`
--

CREATE TABLE `flight` (
  `flight_id` int(11) NOT NULL,
  `departure_time` datetime NOT NULL,
  `arrival_time` datetime NOT NULL,
  `price` decimal(10,2) NOT NULL,
  `Admin_admin_id` int(11) NOT NULL,
  `Plane_Plane_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `flight`
--

INSERT INTO `flight` (`flight_id`, `departure_time`, `arrival_time`, `price`, `Admin_admin_id`, `Plane_Plane_id`) VALUES
(2, '2025-06-20 07:30:00', '2025-06-20 10:00:00', 1500000.00, 1, 1),
(3, '2025-06-20 19:30:00', '2025-06-20 21:00:00', 1000000.00, 1, 1),
(4, '2025-06-20 07:30:00', '2025-06-20 10:00:00', 1500000.00, 1, 1),
(5, '2025-06-23 07:30:00', '2025-06-23 10:00:00', 1500000.00, 1, 1);

-- --------------------------------------------------------

--
-- Struktur dari tabel `flight_airport`
--

CREATE TABLE `flight_airport` (
  `flight_airport_id` int(11) NOT NULL,
  `Flight_flight_id` int(11) NOT NULL,
  `Airport_airport_id` int(11) NOT NULL,
  `direction` enum('arrival','departure') NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `flight_airport`
--

INSERT INTO `flight_airport` (`flight_airport_id`, `Flight_flight_id`, `Airport_airport_id`, `direction`) VALUES
(5, 2, 1, 'departure'),
(6, 2, 5, 'arrival'),
(7, 3, 1, 'departure'),
(8, 3, 5, 'arrival'),
(9, 4, 1, 'departure'),
(10, 4, 5, 'arrival'),
(11, 5, 1, 'departure'),
(12, 5, 5, 'arrival');

-- --------------------------------------------------------

--
-- Stand-in struktur untuk tampilan `flight_details`
-- (Lihat di bawah untuk tampilan aktual)
--
CREATE TABLE `flight_details` (
`flight_id` int(11)
,`departure_time` datetime
,`arrival_time` datetime
,`departure_iata` char(3)
,`arrival_iata` char(3)
,`departure_city` varchar(100)
,`arrival_city` varchar(100)
,`class_name` varchar(20)
,`adjusted_price` decimal(13,4)
,`duration_minutes` bigint(21)
);

-- --------------------------------------------------------

--
-- Struktur dari tabel `payment`
--

CREATE TABLE `payment` (
  `payment_id` int(11) NOT NULL,
  `payment_date` datetime NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `payment_method` varchar(10) NOT NULL,
  `payment_status` enum('paid','pending','failed') NOT NULL,
  `Ticket_ticket_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `payment`
--

INSERT INTO `payment` (`payment_id`, `payment_date`, `amount`, `payment_method`, `payment_status`, `Ticket_ticket_id`) VALUES
(1, '2025-06-14 19:21:26', 1875000.00, 'BCA', 'failed', 1),
(2, '2025-06-14 19:23:44', 1875000.00, 'BCA', 'pending', 2),
(3, '2025-06-14 19:58:10', 1875000.00, 'BCA', 'pending', 3),
(4, '2025-06-14 19:59:07', 1875000.00, 'BCA', 'paid', 4),
(5, '2025-06-21 16:55:28', 1875000.00, 'Credit Car', 'pending', 5),
(6, '2025-06-21 17:03:21', 1875000.00, 'Credit Car', 'pending', 6),
(7, '2025-06-21 17:05:20', 1875000.00, 'Credit Car', 'pending', 7),
(8, '2025-06-21 17:05:38', 1875000.00, 'Credit Car', 'pending', 8),
(9, '2025-06-21 17:05:49', 1875000.00, 'Credit Car', 'pending', 9),
(10, '2025-06-21 17:06:22', 2250000.00, 'Credit Car', 'failed', 10),
(11, '2025-06-21 17:06:50', 1250000.00, 'Credit Car', 'pending', 11),
(12, '2025-06-21 17:08:34', 1250000.00, 'Credit Car', 'pending', 12),
(13, '2025-06-21 17:10:28', 1250000.00, 'Credit Car', 'pending', 13),
(14, '2025-06-21 17:13:12', 1250000.00, 'Credit Car', 'pending', 14);

-- --------------------------------------------------------

--
-- Struktur dari tabel `paymenthistory`
--

CREATE TABLE `paymenthistory` (
  `history_id` int(11) NOT NULL,
  `status` enum('paid','pending','failed') NOT NULL,
  `change_time` datetime NOT NULL,
  `Payment_payment_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `paymenthistory`
--

INSERT INTO `paymenthistory` (`history_id`, `status`, `change_time`, `Payment_payment_id`) VALUES
(1, 'pending', '2025-06-14 19:21:26', 1),
(2, 'pending', '2025-06-14 19:23:44', 2),
(3, 'pending', '2025-06-14 19:58:10', 3),
(4, 'pending', '2025-06-14 19:59:07', 4),
(5, 'paid', '2025-06-14 20:22:36', 4),
(6, 'paid', '2025-06-21 17:21:20', 10);

-- --------------------------------------------------------

--
-- Struktur dari tabel `plane`
--

CREATE TABLE `plane` (
  `Plane_id` int(11) NOT NULL,
  `Plane_code` varchar(10) NOT NULL,
  `plane_model` varchar(20) NOT NULL,
  `seat_capacity` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `plane`
--

INSERT INTO `plane` (`Plane_id`, `Plane_code`, `plane_model`, `seat_capacity`) VALUES
(1, 'B738', '737-800', 189);

-- --------------------------------------------------------

--
-- Struktur dari tabel `seat`
--

CREATE TABLE `seat` (
  `seat_number` char(3) NOT NULL,
  `Plane_Plane_id` int(11) NOT NULL,
  `Class_class_id` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `seat`
--

INSERT INTO `seat` (`seat_number`, `Plane_Plane_id`, `Class_class_id`) VALUES
('1A', 1, 1),
('1B', 1, 1),
('1E', 1, 1),
('1F', 1, 1),
('2A', 1, 1),
('2B', 1, 1),
('2E', 1, 1),
('2F', 1, 1),
('3A', 1, 1),
('3B', 1, 1),
('3E', 1, 1),
('3F', 1, 1),
('4A', 1, 1),
('4B', 1, 1),
('4E', 1, 1),
('4F', 1, 1),
('5A', 1, 2);

-- --------------------------------------------------------

--
-- Struktur dari tabel `seatflight`
--

CREATE TABLE `seatflight` (
  `seat_number` char(3) NOT NULL,
  `Plane_Plane_id` int(11) NOT NULL,
  `Flight_flight_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `seatflight`
--

INSERT INTO `seatflight` (`seat_number`, `Plane_Plane_id`, `Flight_flight_id`) VALUES
('1A', 1, 2),
('1A', 1, 3),
('1A', 1, 4),
('1A', 1, 5),
('1F', 1, 2),
('2A', 1, 2),
('2A', 1, 3),
('2A', 1, 5),
('3A', 1, 3),
('3A', 1, 5),
('4A', 1, 2),
('4A', 1, 3),
('4A', 1, 5),
('4F', 1, 2);

-- --------------------------------------------------------

--
-- Struktur dari tabel `ticket`
--

CREATE TABLE `ticket` (
  `ticket_id` int(11) NOT NULL,
  `book_date` datetime NOT NULL,
  `seat_number` varchar(3) NOT NULL,
  `status` enum('booked','pending','cancelled') NOT NULL,
  `User_user_id` int(11) NOT NULL,
  `Class_class_id` int(11) NOT NULL,
  `Flight_flight_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `ticket`
--

INSERT INTO `ticket` (`ticket_id`, `book_date`, `seat_number`, `status`, `User_user_id`, `Class_class_id`, `Flight_flight_id`) VALUES
(1, '2025-06-14 19:21:26', '3A', 'cancelled', 1, 1, 2),
(2, '2025-06-14 19:23:44', '4A', 'booked', 1, 1, 2),
(3, '2025-06-14 19:58:10', '1F', 'pending', 1, 1, 2),
(4, '2025-06-14 19:59:07', '4F', 'booked', 1, 1, 2),
(5, '2025-06-21 16:55:28', '1A', 'pending', 1, 1, 4),
(6, '2025-06-21 17:03:21', '1A', 'pending', 1, 1, 5),
(7, '2025-06-21 17:05:20', '2A', 'pending', 1, 1, 5),
(8, '2025-06-21 17:05:38', '3A', 'pending', 1, 1, 5),
(9, '2025-06-21 17:05:49', '4A', 'pending', 1, 1, 5),
(10, '2025-06-21 17:06:22', '5A', 'cancelled', 1, 2, 5),
(11, '2025-06-21 17:06:50', '1A', 'pending', 1, 1, 3),
(12, '2025-06-21 17:08:34', '2A', 'pending', 1, 1, 3),
(13, '2025-06-21 17:10:28', '3A', 'pending', 1, 1, 3),
(14, '2025-06-21 17:13:12', '4A', 'pending', 1, 1, 3);

--
-- Trigger `ticket`
--
DELIMITER $$
CREATE TRIGGER `log_booking_activity` AFTER INSERT ON `ticket` FOR EACH ROW BEGIN
    INSERT INTO activitylog (
        activity_type,
        activity_time,
        description,
        User_user_id
    ) VALUES (
        'Booking',
        NOW(),
        CONCAT('User memesan tiket flight ', NEW.Flight_flight_id, ', seat ', NEW.seat_number),
        NEW.User_user_id
    );
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Struktur dari tabel `user`
--

CREATE TABLE `user` (
  `user_id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `email` varchar(100) CHARACTER SET utf8 COLLATE utf8_general_ci NOT NULL,
  `password` varchar(100) NOT NULL,
  `phone_number` varchar(15) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

--
-- Dumping data untuk tabel `user`
--

INSERT INTO `user` (`user_id`, `name`, `email`, `password`, `phone_number`) VALUES
(1, 'Budi Bijaksana', 'budibijaksana@gmail.com', 'budibijak09', '08820192832');

-- --------------------------------------------------------

--
-- Stand-in struktur untuk tampilan `view_available_seats_only`
-- (Lihat di bawah untuk tampilan aktual)
--
CREATE TABLE `view_available_seats_only` (
`flight_id` int(11)
,`seat_number` char(3)
,`class_name` varchar(20)
,`total_price` decimal(13,4)
);

-- --------------------------------------------------------

--
-- Stand-in struktur untuk tampilan `view_user_tickets`
-- (Lihat di bawah untuk tampilan aktual)
--
CREATE TABLE `view_user_tickets` (
`ticket_id` int(11)
,`ticket_status` enum('booked','pending','cancelled')
,`book_date` datetime
,`seat_number` varchar(3)
,`class_name` varchar(20)
,`name` varchar(100)
,`departure_time` datetime
,`arrival_time` datetime
,`departure_iata` char(3)
,`arrival_iata` char(3)
,`price` decimal(12,2)
);

-- --------------------------------------------------------

--
-- Struktur untuk view `flight_details`
--
DROP TABLE IF EXISTS `flight_details`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `flight_details`  AS SELECT `f`.`flight_id` AS `flight_id`, `f`.`departure_time` AS `departure_time`, `f`.`arrival_time` AS `arrival_time`, `a_depart`.`iata_code` AS `departure_iata`, `a_arrive`.`iata_code` AS `arrival_iata`, `a_depart`.`City` AS `departure_city`, `a_arrive`.`City` AS `arrival_city`, `c`.`class_name` AS `class_name`, `f`.`price`* `c`.`price_multiplier` AS `adjusted_price`, timestampdiff(MINUTE,`f`.`departure_time`,`f`.`arrival_time`) AS `duration_minutes` FROM (((((`flight` `f` join `class` `c`) join `flight_airport` `fa_depart` on(`fa_depart`.`Flight_flight_id` = `f`.`flight_id` and `fa_depart`.`direction` = 'departure')) join `airport` `a_depart` on(`a_depart`.`Airport_id` = `fa_depart`.`Airport_airport_id`)) join `flight_airport` `fa_arrive` on(`fa_arrive`.`Flight_flight_id` = `f`.`flight_id` and `fa_arrive`.`direction` = 'arrival')) join `airport` `a_arrive` on(`a_arrive`.`Airport_id` = `fa_arrive`.`Airport_airport_id`)) ;

-- --------------------------------------------------------

--
-- Struktur untuk view `view_available_seats_only`
--
DROP TABLE IF EXISTS `view_available_seats_only`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_available_seats_only`  AS SELECT `f`.`flight_id` AS `flight_id`, `s`.`seat_number` AS `seat_number`, `c`.`class_name` AS `class_name`, `f`.`price`* `c`.`price_multiplier` AS `total_price` FROM (((`flight` `f` join `seat` `s` on(`s`.`Plane_Plane_id` = `f`.`Plane_Plane_id`)) join `class` `c` on(`c`.`class_id` = `s`.`Class_class_id`)) left join `seatflight` `sf` on(`sf`.`seat_number` = `s`.`seat_number` and `sf`.`Plane_Plane_id` = `s`.`Plane_Plane_id` and `sf`.`Flight_flight_id` = `f`.`flight_id`)) WHERE `sf`.`Flight_flight_id` is null ;

-- --------------------------------------------------------

--
-- Struktur untuk view `view_user_tickets`
--
DROP TABLE IF EXISTS `view_user_tickets`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`localhost` SQL SECURITY DEFINER VIEW `view_user_tickets`  AS SELECT `t`.`ticket_id` AS `ticket_id`, `t`.`status` AS `ticket_status`, `t`.`book_date` AS `book_date`, `t`.`seat_number` AS `seat_number`, `c`.`class_name` AS `class_name`, `u`.`name` AS `name`, `f`.`departure_time` AS `departure_time`, `f`.`arrival_time` AS `arrival_time`, `a_depart`.`iata_code` AS `departure_iata`, `a_arrive`.`iata_code` AS `arrival_iata`, round(`f`.`price` * `c`.`price_multiplier`,2) AS `price` FROM (((((((`ticket` `t` join `class` `c` on(`t`.`Class_class_id` = `c`.`class_id`)) join `flight` `f` on(`t`.`Flight_flight_id` = `f`.`flight_id`)) join `user` `u` on(`t`.`User_user_id` = `u`.`user_id`)) join `flight_airport` `fa_depart` on(`fa_depart`.`Flight_flight_id` = `f`.`flight_id` and `fa_depart`.`direction` = 'departure')) join `airport` `a_depart` on(`a_depart`.`Airport_id` = `fa_depart`.`Airport_airport_id`)) join `flight_airport` `fa_arrive` on(`fa_arrive`.`Flight_flight_id` = `f`.`flight_id` and `fa_arrive`.`direction` = 'arrival')) join `airport` `a_arrive` on(`a_arrive`.`Airport_id` = `fa_arrive`.`Airport_airport_id`)) ;

--
-- Indexes for dumped tables
--

--
-- Indeks untuk tabel `activitylog`
--
ALTER TABLE `activitylog`
  ADD PRIMARY KEY (`log_id`),
  ADD KEY `ActivityLog_User` (`User_user_id`);

--
-- Indeks untuk tabel `admin`
--
ALTER TABLE `admin`
  ADD PRIMARY KEY (`admin_id`),
  ADD UNIQUE KEY `idx_email` (`Email`);

--
-- Indeks untuk tabel `airport`
--
ALTER TABLE `airport`
  ADD PRIMARY KEY (`Airport_id`),
  ADD UNIQUE KEY `idx_iata_code` (`iata_code`),
  ADD KEY `idx_city` (`City`);

--
-- Indeks untuk tabel `class`
--
ALTER TABLE `class`
  ADD PRIMARY KEY (`class_id`),
  ADD KEY `idx_class_name` (`class_name`);

--
-- Indeks untuk tabel `flight`
--
ALTER TABLE `flight`
  ADD PRIMARY KEY (`flight_id`),
  ADD KEY `Flight_Admin` (`Admin_admin_id`),
  ADD KEY `Flight_Plane` (`Plane_Plane_id`);

--
-- Indeks untuk tabel `flight_airport`
--
ALTER TABLE `flight_airport`
  ADD PRIMARY KEY (`flight_airport_id`),
  ADD KEY `Route_Airport` (`Airport_airport_id`),
  ADD KEY `Route_Flight` (`Flight_flight_id`);

--
-- Indeks untuk tabel `payment`
--
ALTER TABLE `payment`
  ADD PRIMARY KEY (`payment_id`),
  ADD KEY `Payment_Ticket` (`Ticket_ticket_id`);

--
-- Indeks untuk tabel `paymenthistory`
--
ALTER TABLE `paymenthistory`
  ADD PRIMARY KEY (`history_id`),
  ADD KEY `PaymentHistory_Payment` (`Payment_payment_id`);

--
-- Indeks untuk tabel `plane`
--
ALTER TABLE `plane`
  ADD PRIMARY KEY (`Plane_id`),
  ADD KEY `idx_plane_code_model` (`Plane_code`,`plane_model`);

--
-- Indeks untuk tabel `seat`
--
ALTER TABLE `seat`
  ADD PRIMARY KEY (`seat_number`,`Plane_Plane_id`),
  ADD KEY `FK_PlaneSeat` (`Plane_Plane_id`),
  ADD KEY `FK_SeatClass` (`Class_class_id`);

--
-- Indeks untuk tabel `seatflight`
--
ALTER TABLE `seatflight`
  ADD PRIMARY KEY (`seat_number`,`Plane_Plane_id`,`Flight_flight_id`),
  ADD KEY `FK_SeatFlight_Flight` (`Flight_flight_id`);

--
-- Indeks untuk tabel `ticket`
--
ALTER TABLE `ticket`
  ADD PRIMARY KEY (`ticket_id`),
  ADD KEY `Ticket_Class` (`Class_class_id`),
  ADD KEY `Ticket_Flight` (`Flight_flight_id`),
  ADD KEY `idx_ticket_user_flight_class_status` (`User_user_id`,`Flight_flight_id`,`Class_class_id`,`status`);

--
-- Indeks untuk tabel `user`
--
ALTER TABLE `user`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `idx_email` (`email`);

--
-- AUTO_INCREMENT untuk tabel yang dibuang
--

--
-- AUTO_INCREMENT untuk tabel `activitylog`
--
ALTER TABLE `activitylog`
  MODIFY `log_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT untuk tabel `admin`
--
ALTER TABLE `admin`
  MODIFY `admin_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT untuk tabel `airport`
--
ALTER TABLE `airport`
  MODIFY `Airport_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT untuk tabel `flight`
--
ALTER TABLE `flight`
  MODIFY `flight_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT untuk tabel `flight_airport`
--
ALTER TABLE `flight_airport`
  MODIFY `flight_airport_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=13;

--
-- AUTO_INCREMENT untuk tabel `payment`
--
ALTER TABLE `payment`
  MODIFY `payment_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT untuk tabel `paymenthistory`
--
ALTER TABLE `paymenthistory`
  MODIFY `history_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT untuk tabel `plane`
--
ALTER TABLE `plane`
  MODIFY `Plane_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT untuk tabel `ticket`
--
ALTER TABLE `ticket`
  MODIFY `ticket_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT untuk tabel `user`
--
ALTER TABLE `user`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- Ketidakleluasaan untuk tabel pelimpahan (Dumped Tables)
--

--
-- Ketidakleluasaan untuk tabel `activitylog`
--
ALTER TABLE `activitylog`
  ADD CONSTRAINT `ActivityLog_User` FOREIGN KEY (`User_user_id`) REFERENCES `user` (`user_id`);

--
-- Ketidakleluasaan untuk tabel `flight`
--
ALTER TABLE `flight`
  ADD CONSTRAINT `Flight_Admin` FOREIGN KEY (`Admin_admin_id`) REFERENCES `admin` (`admin_id`),
  ADD CONSTRAINT `Flight_Plane` FOREIGN KEY (`Plane_Plane_id`) REFERENCES `plane` (`Plane_id`);

--
-- Ketidakleluasaan untuk tabel `flight_airport`
--
ALTER TABLE `flight_airport`
  ADD CONSTRAINT `Route_Airport` FOREIGN KEY (`Airport_airport_id`) REFERENCES `airport` (`Airport_id`),
  ADD CONSTRAINT `Route_Flight` FOREIGN KEY (`Flight_flight_id`) REFERENCES `flight` (`flight_id`);

--
-- Ketidakleluasaan untuk tabel `payment`
--
ALTER TABLE `payment`
  ADD CONSTRAINT `Payment_Ticket` FOREIGN KEY (`Ticket_ticket_id`) REFERENCES `ticket` (`ticket_id`);

--
-- Ketidakleluasaan untuk tabel `paymenthistory`
--
ALTER TABLE `paymenthistory`
  ADD CONSTRAINT `PaymentHistory_Payment` FOREIGN KEY (`Payment_payment_id`) REFERENCES `payment` (`payment_id`);

--
-- Ketidakleluasaan untuk tabel `seat`
--
ALTER TABLE `seat`
  ADD CONSTRAINT `FK_PlaneSeat` FOREIGN KEY (`Plane_plane_id`) REFERENCES `plane` (`Plane_id`),
  ADD CONSTRAINT `FK_SeatClass` FOREIGN KEY (`Class_class_id`) REFERENCES `class` (`class_id`);

--
-- Ketidakleluasaan untuk tabel `seatflight`
--
ALTER TABLE `seatflight`
  ADD CONSTRAINT `FK_SeatFlight_Flight` FOREIGN KEY (`Flight_flight_id`) REFERENCES `flight` (`flight_id`),
  ADD CONSTRAINT `FK_SeatFlight_Seat` FOREIGN KEY (`seat_number`,`Plane_plane_id`) REFERENCES `seat` (`seat_number`, `Plane_plane_id`);

--
-- Ketidakleluasaan untuk tabel `ticket`
--
ALTER TABLE `ticket`
  ADD CONSTRAINT `Ticket_Class` FOREIGN KEY (`Class_class_id`) REFERENCES `class` (`class_id`),
  ADD CONSTRAINT `Ticket_Flight` FOREIGN KEY (`Flight_flight_id`) REFERENCES `flight` (`flight_id`),
  ADD CONSTRAINT `Ticket_User` FOREIGN KEY (`User_user_id`) REFERENCES `user` (`user_id`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
