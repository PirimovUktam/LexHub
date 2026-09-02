"""BLACK-HOLE TCP server — qotib qolgan socket modelini takrorlaydi.

Ulanishni QABUL QILADI, lekin BIRORTA bayt ham qaytarmaydi va socket'ni ochiq
saqlaydi. TLS handshake shu bosqichda qotadi, ya'ni `http` mijozining
`send()` chaqiruvi hech qachon tugamaydi — `TimeoutHttpClient` qo'ygan chegara
ISHLAMASA, ilova cheksiz spinner ko'rsatadi.

HAR BIR ULANISH VAQT BILAN yoziladi: release build'da `debugPrint` yo'q, ya'ni
`adb logcat` da Dart darajasidagi izoh QOLMAYDI. Shu sababli ulanish
timeline'i — qaysi so'rov qachon boshlangani va urinishlar orasidagi masofa —
yagona ishonchli runtime signal. Masofa chegaraga teng bo'lsa, so'rov
CHEGARALANGAN; ulanish BITTA bo'lib qolsa, chegara ishlamayapti.

Ishlatilishi (emulator uchun host tomonda):
    python tool/blackhole_server.py 13500
"""
import socket
import sys
import threading
import time

HOLD = []  # socket'lar yopilmasligi uchun referens saqlanadi
START = time.monotonic()


def main() -> None:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 13500
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("0.0.0.0", port))
    srv.listen(64)
    print(f"[blackhole] 0.0.0.0:{port} tinglanmoqda — javob BERILMAYDI", flush=True)

    count = 0
    while True:
        conn, addr = srv.accept()
        HOLD.append(conn)
        count += 1
        print(
            f"[blackhole] #{count:03d} {time.strftime('%H:%M:%S')} "
            f"(+{time.monotonic() - START:7.2f}s) {addr[0]}:{addr[1]} — javob yo'q",
            flush=True,
        )
        threading.Thread(target=lambda c=conn: c.recv(65535), daemon=True).start()


if __name__ == "__main__":
    main()
