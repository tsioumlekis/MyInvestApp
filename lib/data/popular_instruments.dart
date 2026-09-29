import '../models/holding.dart';
import 'instrument_search.dart';

/// Δημοφιλή προϊόντα, διαθέσιμα χωρίς internet.
const popularInstruments = <Instrument>[
  // ETF (UCITS, διαθέσιμα σε Ευρωπαίους επενδυτές)
  Instrument('VWCE', 'Vanguard FTSE All-World UCITS ETF (Acc)', 'XETR', 'EUR', AssetType.etf),
  Instrument('IWDA', 'iShares Core MSCI World UCITS ETF (Acc)', 'Euronext', 'EUR', AssetType.etf),
  Instrument('EUNL', 'iShares Core MSCI World UCITS ETF (Acc)', 'XETR', 'EUR', AssetType.etf),
  Instrument('SXR8', 'iShares Core S&P 500 UCITS ETF (Acc)', 'XETR', 'EUR', AssetType.etf),
  Instrument('CSPX', 'iShares Core S&P 500 UCITS ETF (Acc)', 'LSE', 'USD', AssetType.etf),
  Instrument('VUAA', 'Vanguard S&P 500 UCITS ETF (Acc)', 'XETR', 'EUR', AssetType.etf),
  Instrument('VUSA', 'Vanguard S&P 500 UCITS ETF (Dist)', 'XETR', 'EUR', AssetType.etf),
  Instrument('EQQQ', 'Invesco EQQQ Nasdaq-100 UCITS ETF', 'XETR', 'EUR', AssetType.etf),
  Instrument('EIMI', 'iShares Core MSCI EM IMI UCITS ETF', 'LSE', 'USD', AssetType.etf),
  // ETF ΗΠΑ
  Instrument('VOO', 'Vanguard S&P 500 ETF', 'NYSE', 'USD', AssetType.etf),
  Instrument('SPY', 'SPDR S&P 500 ETF Trust', 'NYSE', 'USD', AssetType.etf),
  Instrument('QQQ', 'Invesco QQQ Trust', 'NASDAQ', 'USD', AssetType.etf),
  // Μετοχές ΗΠΑ
  Instrument('AAPL', 'Apple Inc.', 'NASDAQ', 'USD', AssetType.stock),
  Instrument('MSFT', 'Microsoft Corporation', 'NASDAQ', 'USD', AssetType.stock),
  Instrument('NVDA', 'NVIDIA Corporation', 'NASDAQ', 'USD', AssetType.stock),
  Instrument('AMZN', 'Amazon.com Inc.', 'NASDAQ', 'USD', AssetType.stock),
  Instrument('GOOGL', 'Alphabet Inc. (Class A)', 'NASDAQ', 'USD', AssetType.stock),
  Instrument('META', 'Meta Platforms Inc.', 'NASDAQ', 'USD', AssetType.stock),
  Instrument('TSLA', 'Tesla Inc.', 'NASDAQ', 'USD', AssetType.stock),
  Instrument('AVGO', 'Broadcom Inc.', 'NASDAQ', 'USD', AssetType.stock),
  Instrument('AMD', 'Advanced Micro Devices Inc.', 'NASDAQ', 'USD', AssetType.stock),
  Instrument('NFLX', 'Netflix Inc.', 'NASDAQ', 'USD', AssetType.stock),
  Instrument('PLTR', 'Palantir Technologies Inc.', 'NASDAQ', 'USD', AssetType.stock),
  Instrument('BRK.B', 'Berkshire Hathaway Inc. (Class B)', 'NYSE', 'USD', AssetType.stock),
  Instrument('JPM', 'JPMorgan Chase & Co.', 'NYSE', 'USD', AssetType.stock),
  Instrument('V', 'Visa Inc.', 'NYSE', 'USD', AssetType.stock),
  Instrument('KO', 'The Coca-Cola Company', 'NYSE', 'USD', AssetType.stock),
  // Χρηματιστήριο Αθηνών
  Instrument('ETE', 'Εθνική Τράπεζα της Ελλάδος', 'ATHEX', 'EUR', AssetType.stock),
  Instrument('ALPHA', 'Alpha Bank', 'ATHEX', 'EUR', AssetType.stock),
  Instrument('EUROB', 'Eurobank Ergasias', 'ATHEX', 'EUR', AssetType.stock),
  Instrument('TPEIR', 'Τράπεζα Πειραιώς', 'ATHEX', 'EUR', AssetType.stock),
  Instrument('OPAP', 'ΟΠΑΠ', 'ATHEX', 'EUR', AssetType.stock),
  Instrument('PPC', 'ΔΕΗ', 'ATHEX', 'EUR', AssetType.stock),
  Instrument('HTO', 'ΟΤΕ', 'ATHEX', 'EUR', AssetType.stock),
  Instrument('METLEN', 'Metlen Energy & Metals', 'ATHEX', 'EUR', AssetType.stock),
  Instrument('MOH', 'Motor Oil Hellas', 'ATHEX', 'EUR', AssetType.stock),
  Instrument('BELA', 'Jumbo', 'ATHEX', 'EUR', AssetType.stock),
  Instrument('GEKTERNA', 'ΓΕΚ ΤΕΡΝΑ', 'ATHEX', 'EUR', AssetType.stock),
  Instrument('ELPE', 'HELLENiQ ENERGY', 'ATHEX', 'EUR', AssetType.stock),
  Instrument('AEGN', 'Aegean Airlines', 'ATHEX', 'EUR', AssetType.stock),
  // Crypto
  Instrument('BTC', 'Bitcoin', '', 'EUR', AssetType.crypto),
  Instrument('ETH', 'Ethereum', '', 'EUR', AssetType.crypto),
  Instrument('SOL', 'Solana', '', 'EUR', AssetType.crypto),
  Instrument('XRP', 'XRP', '', 'EUR', AssetType.crypto),
  Instrument('ADA', 'Cardano', '', 'EUR', AssetType.crypto),
  Instrument('DOGE', 'Dogecoin', '', 'EUR', AssetType.crypto),
];
