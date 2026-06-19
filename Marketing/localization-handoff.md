# App Store Connect Localization — Computer-Use Agent Handoff

## Goal
Localize the **Unplug Screentime** App Store listing into 9 languages (de, es, fr, it,
pt-PT, ja, ko, zh-Hans, zh-Hant). For each: add the localization, enter the translated
**Subtitle / Description / Keywords**, and upload the 4 localized **screenshots**.

## Who/what runs this
A **desktop computer-use agent** (full screen control) driving Chrome. Desktop control is
required because uploading screenshots needs the native macOS "Choose File" open dialog — the
browser-only file-upload path does not work here. Text entry is plain clicking + typing into
fields (Unicode/CJK paste directly).

## Hard safety rules
1. **Do NOT click "Add for Review" or submit the version.** Only enter data and let it
   auto-save (App Store Connect saves field edits on blur). Leave the version in
   "Prepare for Submission".
2. **Pause and ask the human before any irreversible action** (submitting, deleting all
   screenshots of a locale you didn't just create, changing pricing/availability).
3. Precondition noted by the team: the developer account US→Ireland move should be complete
   before final submission. Localizing drafts now is fine; **do not submit** until confirmed.
4. If the App Store Connect session is logged out, **stop and ask the human to log in**
   (2FA must be done by them). Do not attempt to enter credentials.

## App / URLs
- App ID: `6462699154`
- Version (Subtitle? no — see below; Description/Keywords/Screenshots): `https://appstoreconnect.apple.com/apps/6462699154/distribution/ios/version/inflight`
- App Information (Name + **Subtitle**, app-level localization): `https://appstoreconnect.apple.com/apps/6462699154/distribution/info`
- Media Manager (screenshots, all sizes): `https://appstoreconnect.apple.com/apps/6462699154/distribution/ios/version/inflight/media-manager/iphone`

## Where each field lives (important)
- **Name** and **Subtitle** are localized on the **App Information** page.
- **Description, Keywords, Promotional Text, What's New, Screenshots** are localized on the
  **Version 1.3** page.
- Both pages have a **language dropdown** (top-right, default "English (U.S.)") with an
  **Add Language** option. Adding a language exposes empty localized fields to fill.

## Per-locale procedure (repeat for all 9)
1. **App Information page** → language dropdown → **Add Language** → select the locale.
   - **Name**: `Unplug Screentime` (keep the brand — do NOT translate).
   - **Subtitle**: paste the localized subtitle (≤30 chars — watch the counter).
2. **Version 1.3 page** → language dropdown → select the same locale (add if prompted).
   - **Description**: paste the localized description.
   - **Keywords**: paste the localized keywords (≤100 chars — watch the counter; trim last
     terms if it turns red).
   - Leave **Promotional Text** and **What's New** empty (English leaves them empty).
3. **Screenshots** (Version page → Previews and Screenshots → **iPhone 6.5" Display**, with
   the locale selected in the dropdown):
   - Click **Choose File** → in the native dialog, select all four files from
     `/Users/stevendiviney/code/ScreenTimeShield/Marketing/<locale>/` in order
     `app_store_1.png, app_store_2.png, app_store_3.png, app_store_4.png`.
   - Confirm they appear in order 1→2→3→4 (drag to reorder if needed). Only the 6.5" slot is
     needed — Apple scales it to the other sizes.
4. Verify the locale's three text fields + 4 screenshots are present, then move to the next.

## Verification checklist (per locale)
- Subtitle present, no red over-limit warning.
- Description present and not truncated.
- Keywords present, counter not red.
- Exactly 4 screenshots in the 6.5" slot, order 1→4.
- Screenshot files are 1242×2688 (already verified during creation).

## Cleanup tasks (do once, ask human first)
- The **English 5.5" Display** section still holds the OLD (pre-redesign) screenshots from a
  prior pass. Either delete them (so Apple falls back to the new 6.5" set) or leave — confirm
  with the human.

---

# Localized copy to paste

> Source of truth = the live English fields (Subtitle / Description / Keywords). These
> translations mirror them and align to the in-app terminology in `Localizable.xcstrings`.
> Translations are drafts pending native review. App **Name** stays `Unplug Screentime`
> in every locale.

## German (de)

**Subtitle:** `Unumgehbare App-Limits`

**Keywords:** `bildschirmzeit,app blocker,fokus,digital detox,handysucht,app limit,apps sperren,doomscrolling`

**Description:**
```
Bildschirmzeit-Limits lassen sich in 10 Sekunden umgehen. Unplug nicht.

Lege einen Zeitplan fest. Wähle deine Apps. Wenn die Sperre aktiv ist, gibt es kein Übergehen, keinen Trick mit dem Code, kein „nur noch 15 Minuten". Die Apps bleiben gesperrt, bis deine Zeit um ist.

SO FUNKTIONIERT ES
Wähle die Apps und Websites, die blockiert werden sollen. Lege Start- und Endzeit fest. Unplug sperrt sie nach Plan – ganz ohne Willenskraft.

WARUM ES ANDERS IST
Bei der nativen Bildschirmzeit tippst du auf „Limit ignorieren" und scrollst weiter. Unplug nutzt Apples Framework zur Geräteverwaltung, um Einschränkungen durchzusetzen, die sich nicht aufheben lassen. Es gibt keine Hintertür.

DAS BEKOMMST DU
· Unumgehbares Blockieren von Apps und Websites nach Tagesplan
· Schnellsperre: Apps mit einem Tippen für die nächste Stunde sperren
· Refokus-Benachrichtigungen, wenn du gesperrte Apps außerhalb der Sperrzeiten öffnest
· Funktioniert mit jeder App und Website
· Kein Konto nötig, keine Datenerfassung

Einmaliger Kauf. Kein Abo. Keine Werbung.

Unplug – Limits nicht nur setzen. Sperren.
```

## Spanish (es)

**Subtitle:** `Límites que no puedes saltar`

**Keywords:** `tiempo de uso,bloqueo apps,concentración,detox digital,adicción móvil,limitar apps,bloquear webs`

**Description:**
```
Los límites de Tiempo de Uso se saltan en 10 segundos. Unplug no.

Define un horario. Elige tus apps. Cuando el bloqueo está activo, no hay forma de anularlo, ni truco con el código, ni "solo 15 minutos más". Las apps quedan bloqueadas hasta que se acabe tu tiempo.

CÓMO FUNCIONA
Elige qué apps y webs bloquear. Define la hora de inicio y de fin. Unplug las bloquea según el horario, sin fuerza de voluntad.

POR QUÉ ES DIFERENTE
Con el Tiempo de Uso nativo, tocas "Ignorar límite" y vuelves a deslizar. Unplug usa el marco de gestión de dispositivos de Apple para aplicar restricciones que no se pueden descartar. No hay puerta trasera.

QUÉ INCLUYE
· Bloqueo imposible de saltar de apps y webs con horario diario
· Bloqueo rápido: restringe apps durante la próxima hora con un toque
· Notificaciones de reenfoque cuando abres apps restringidas fuera del horario
· Funciona con cualquier app o web
· Sin cuenta, sin recopilación de datos

Pago único. Sin suscripción. Sin anuncios.

Unplug: no solo pongas límites. Bloquéalos.
```

## French (fr)

**Subtitle:** `Des limites incontournables`

**Keywords:** `temps d'écran,bloqueur d'apps,concentration,détox digitale,addiction tél,limiter apps,bloquer sites`

**Description:**
```
Les limites de Temps d'écran se contournent en 10 secondes. Pas Unplug.

Définissez un horaire. Choisissez vos apps. Quand le blocage est actif, pas de contournement, pas d'astuce avec le code, pas de « juste 15 minutes de plus ». Les apps restent verrouillées jusqu'à la fin.

COMMENT ÇA MARCHE
Choisissez les apps et sites à bloquer. Définissez l'heure de début et de fin. Unplug les verrouille selon l'horaire, sans effort de volonté.

POURQUOI C'EST DIFFÉRENT
Avec le Temps d'écran natif, vous touchez « Ignorer la limite » et vous reprenez le scroll. Unplug utilise le cadre de gestion des appareils d'Apple pour appliquer des restrictions impossibles à ignorer. Aucune porte dérobée.

CE QUE VOUS OBTENEZ
· Blocage incontournable des apps et sites selon un horaire quotidien
· Blocage express : limitez des apps pour l'heure qui vient en un toucher
· Notifications de recentrage quand vous ouvrez des apps bloquées hors horaire
· Fonctionne avec toute app ou site
· Aucun compte requis, aucune donnée collectée

Achat unique. Pas d'abonnement. Pas de publicité.

Unplug — Ne vous contentez pas de fixer des limites. Verrouillez-les.
```

## Italian (it)

**Subtitle:** `Limiti che non puoi saltare`

**Keywords:** `tempo di utilizzo,blocco app,concentrazione,detox digitale,dipendenza,limita app,blocca siti`

**Description:**
```
I limiti di Tempo di utilizzo si aggirano in 10 secondi. Unplug no.

Imposta un orario. Scegli le tue app. Quando il blocco è attivo, niente scorciatoie, nessun trucco con il codice, nessun "solo altri 15 minuti". Le app restano bloccate finché il tuo tempo non scade.

COME FUNZIONA
Scegli quali app e siti bloccare. Imposta l'ora di inizio e di fine. Unplug li blocca secondo il programma, senza forza di volontà.

PERCHÉ È DIVERSO
Con Tempo di utilizzo nativo basta toccare "Ignora limite" e torni a scorrere. Unplug usa il framework di gestione dei dispositivi di Apple per applicare restrizioni che non si possono ignorare. Nessuna scorciatoia.

COSA OTTIENI
· Blocco di app e siti impossibile da saltare, con programma giornaliero
· Blocco rapido: limita le app per l'ora successiva con un tocco
· Notifiche di rifocalizzazione quando apri app bloccate fuori orario
· Funziona con qualsiasi app o sito
· Nessun account richiesto, nessun dato raccolto

Acquisto singolo. Nessun abbonamento. Nessuna pubblicità.

Unplug — Non limitarti a impostare i limiti. Bloccali.
```

## Portuguese – Portugal (pt-PT)

**Subtitle:** `Limites que não podes saltar`

**Keywords:** `tempo de ecrã,bloquear apps,concentração,detox digital,vício telemóvel,limitar apps,bloquear sites`

**Description:**
```
Os limites do Tempo de Ecrã contornam-se em 10 segundos. O Unplug não.

Define um horário. Escolhe as tuas apps. Quando o bloqueio está ativo, não há forma de anular, nem truque com o código, nem "só mais 15 minutos". As apps ficam bloqueadas até o teu tempo terminar.

COMO FUNCIONA
Escolhe que apps e sites bloquear. Define a hora de início e de fim. O Unplug bloqueia-os segundo o horário, sem força de vontade.

PORQUE É DIFERENTE
No Tempo de Ecrã nativo, tocas em "Ignorar limite" e voltas a deslizar. O Unplug usa a framework de gestão de dispositivos da Apple para aplicar restrições que não podem ser dispensadas. Não há porta das traseiras.

O QUE RECEBES
· Bloqueio impossível de saltar de apps e sites, com horário diário
· Bloqueio rápido: restringe apps na próxima hora com um toque
· Notificações de refoco quando abres apps restritas fora do horário
· Funciona com qualquer app ou site
· Sem conta, sem recolha de dados

Compra única. Sem subscrição. Sem anúncios.

Unplug — Não te limites a definir limites. Bloqueia-os.
```

## Japanese (ja)

**Subtitle:** `解除できない利用制限`

**Keywords:** `スクリーンタイム,アプリ制限,集中,デジタルデトックス,スマホ依存,アプリブロック,時間制限,スクロール防止,集中力`

**Description:**
```
スクリーンタイムの制限は10秒で破れます。Unplugは破れません。

スケジュールを設定し、アプリを選ぶだけ。ブロック中は、解除も、パスコードの抜け道も、「あと15分だけ」もありません。時間になるまでアプリはロックされます。

使い方
ブロックするアプリやウェブサイトを選びます。開始時刻と終了時刻を設定します。あとはUnplugがスケジュール通りにロック。意志の力は要りません。

何が違うのか
標準のスクリーンタイムは「制限を無視」をタップすればすぐにスクロールへ戻れます。UnplugはAppleのデバイス管理フレームワークを使い、解除できない制限を適用します。抜け道はありません。

主な機能
・毎日のスケジュールで、スキップできないアプリ・ウェブサイトのブロック
・クイックブロック：ワンタップで次の1時間アプリを制限
・ブロック時間外に制限中のアプリを開くと、リフォーカス通知
・あらゆるアプリ・ウェブサイトに対応
・アカウント不要、データ収集なし

買い切り。サブスクなし。広告なし。

Unplug — 制限を設定するだけでなく、ロックする。
```

## Korean (ko)

**Subtitle:** `건너뛸 수 없는 사용 제한`

**Keywords:** `스크린타임,앱 차단,집중,디지털 디톡스,스마트폰 중독,앱 제한,웹사이트 차단,도파민 디톡스`

**Description:**
```
스크린 타임 제한은 10초면 뚫립니다. Unplug는 다릅니다.

일정을 정하고 앱을 고르세요. 차단이 활성화되면 해제도, 암호 우회도, "딱 15분만 더"도 없습니다. 시간이 끝날 때까지 앱은 잠깁니다.

사용 방법
차단할 앱과 웹사이트를 선택하세요. 시작 시간과 종료 시간을 설정하세요. Unplug가 일정대로 잠급니다. 의지력은 필요 없습니다.

무엇이 다른가
기본 스크린 타임은 "제한 무시"를 누르면 다시 스크롤로 돌아갑니다. Unplug는 Apple의 기기 관리 프레임워크를 사용해 해제할 수 없는 제한을 적용합니다. 뒷문은 없습니다.

주요 기능
· 매일 일정에 따라 건너뛸 수 없는 앱·웹사이트 차단
· 빠른 차단: 한 번의 탭으로 다음 1시간 동안 앱 제한
· 차단 시간 외에 제한된 앱을 열면 리포커스 알림
· 모든 앱과 웹사이트에서 작동
· 계정 불필요, 데이터 수집 없음

일회성 구매. 구독 없음. 광고 없음.

Unplug — 제한을 정하는 데 그치지 말고, 잠그세요.
```

## Chinese Simplified (zh-Hans)

**Subtitle:** `无法绕过的应用限制`

**Keywords:** `屏幕使用时间,应用阻止,专注,数字戒瘾,手机成瘾,应用限制,网站拦截,防沉迷,戒手机`

**Description:**
```
屏幕使用时间的限制10秒就能绕过，而Unplug不行。

设定时间表，选择应用。在阻止生效期间，没有解除、没有密码漏洞、没有"再玩15分钟"。应用会一直锁定，直到时间结束。

工作原理
选择要阻止的应用和网站，设置开始和结束时间。Unplug会按计划锁定它们——无需意志力。

有何不同
原生的屏幕使用时间，点一下"忽略限制"就能继续刷。Unplug使用Apple的设备管理框架来强制执行无法关闭的限制。没有后门。

功能一览
· 按每日计划阻止应用和网站，无法跳过
· 快速阻止：一键限制应用一小时
· 在阻止时段外打开受限应用时，发送重新专注提醒
· 适用于任何应用或网站
· 无需账户，不收集数据

一次性购买。无订阅。无广告。

Unplug——不只是设定限制，而是锁住它们。
```

## Chinese Traditional (zh-Hant)

**Subtitle:** `無法略過的應用限制`

**Keywords:** `螢幕使用時間,應用程式封鎖,專注,數位戒癮,手機成癮,應用程式限制,網站封鎖,防沉迷,戒手機`

**Description:**
```
螢幕使用時間的限制10秒就能略過，但Unplug不行。

設定時間表，選擇應用程式。在封鎖生效期間，沒有解除、沒有密碼漏洞、沒有「再玩15分鐘」。應用程式會一直鎖定，直到時間結束。

運作方式
選擇要封鎖的應用程式和網站，設定開始與結束時間。Unplug會按計畫鎖定它們——無需意志力。

有何不同
原生的螢幕使用時間，點一下「忽略限制」就能繼續滑。Unplug使用Apple的裝置管理框架來強制執行無法關閉的限制。沒有後門。

功能一覽
· 依每日計畫封鎖應用程式和網站，無法略過
· 快速封鎖：一鍵限制應用程式一小時
· 在封鎖時段外開啟受限應用程式時，發送重新專注通知
· 適用於任何應用程式或網站
· 無需帳戶，不收集資料

一次性購買。無訂閱。無廣告。

Unplug——不只是設定限制，而是鎖住它們。
```

---

## Screenshot file map
For each locale, the 4 files (already 1242×2688, no alpha):
```
Marketing/de/app_store_1.png … app_store_4.png
Marketing/es/…   Marketing/fr/…   Marketing/it/…   Marketing/pt-PT/…
Marketing/ja/…   Marketing/ko/…   Marketing/zh-Hans/…   Marketing/zh-Hant/…
```
(English set: `Marketing/en/app_store_1..4.png`.)

## Char limits (watch the live counters)
| Field | Limit |
|---|---|
| Subtitle | 30 |
| Keywords | 100 |
| Promotional Text | 170 (leave empty) |
| Description | 4000 |
All subtitles/keywords above are within limits; verify in the UI in case of font/count edge cases.
