class JsScripts {
  // ==================== OZON ====================
  
  static const String ozonJsonInterceptor = '''
    (function() {
      const originalFetch = window.fetch;
      const originalXHR = window.XMLHttpRequest;
      
      window.fetch = function(...args) {
        const url = args[0] || '';
        return originalFetch.apply(this, args).then(response => {
          if (url.includes('/api/') && (url.includes('search') || url.includes('product'))) {
            response.clone().json().then(data => {
              if (window.flutter_ozon_handler) {
                window.flutter_ozon_handler.postMessage(JSON.stringify(data));
              }
            }).catch(e => {});
          }
          return response;
        });
      };
      
      const originalOpen = originalXHR.prototype.open;
      const originalSend = originalXHR.prototype.send;
      
      originalXHR.prototype.open = function(method, url, ...rest) {
        this._url = url;
        return originalOpen.apply(this, [method, url, ...rest]);
      };
      
      originalXHR.prototype.send = function(...args) {
        this.addEventListener('load', function() {
          if (this._url && this._url.includes('/api/') && 
              (this._url.includes('search') || this._url.includes('product'))) {
            try {
              const data = JSON.parse(this.responseText);
              if (window.flutter_ozon_handler) {
                window.flutter_ozon_handler.postMessage(JSON.stringify(data));
              }
            } catch(e) {}
          }
        });
        return originalSend.apply(this, args);
      };
      
      console.log('Ozon JSON interceptor installed');
    })();
  ''';

    // 🆕 OZON DOM-ПАРСЕР С АВТО-СКРОЛЛОМ + ОТПРАВКА ЧЕРЕЗ КАНАЛ
  static const String ozonSearchScript = '''
    (async function() {
      const products = [];
      const seen = new Set();
      
      function parseCard(card, index) {
        const linkEl = card.querySelector('a[href*="/product/"]');
        if (!linkEl) return null;
        
        let link = linkEl.href || '';
        if (!link) return null;
        if (link && !link.startsWith('http')) {
          link = 'https://www.ozon.ru' + link;
        }
        
        if (seen.has(link)) return null;
        seen.add(link);
        
        const imgEl = card.querySelector('img');
        let imageUrl = '';
        if (imgEl) {
          imageUrl = imgEl.src || imgEl.getAttribute('data-src') || '';
          if (imageUrl.includes('wc200') || imageUrl.includes('wc300')) {
            imageUrl = imageUrl.replace(/wc\\d+/, 'wc500');
          }
        }
        
        let priceText = '0';
        const priceSection = card.querySelector('.q1b1_5_3-a');
        if (priceSection) {
          const priceEl = priceSection.querySelector('.tsHeadline500Medium');
          if (priceEl) {
            const text = priceEl.innerText || '';
            const match = text.match(/(\\d[\\d\\s]*\\d)/);
            if (match) {
              priceText = match[1].replace(/\\s/g, '');
            }
          }
        }
        
        if (priceText === '0') {
          const allSpans = card.querySelectorAll('span');
          for (let el of allSpans) {
            const text = el.innerText || '';
            if (text.includes('₽') && text.match(/\\d/)) {
              const match = text.match(/(\\d[\\d\\s]*\\d)/);
              if (match) {
                priceText = match[1].replace(/\\s/g, '');
                break;
              }
            }
          }
        }
        
        let name = '';
        const nameEl = card.querySelector('.tsBody500Medium');
        if (nameEl) {
          name = nameEl.innerText.trim();
        }
        
        let rating = 0;
        let salesCount = 0;
        const ratingEls = card.querySelectorAll('.tsBodyControl300XSmall');
        
        if (ratingEls.length > 0) {
          const ratingText = ratingEls[0].innerText || '';
          const ratingMatch = ratingText.match(/(\\d[.,]\\d)/);
          if (ratingMatch) {
            rating = parseFloat(ratingMatch[1].replace(',', '.'));
          }
        }
        
        if (ratingEls.length > 1) {
          const salesText = ratingEls[1].innerText || '';
          const salesMatch = salesText.match(/(\\d[\\d\\s]*)\\s*отзыв/i);
          if (salesMatch) {
            salesCount = parseInt(salesMatch[1].replace(/\\s/g, ''));
          }
        }
        
        return {
          id: 'ozon_' + index + '_' + Date.now(),
          name: name || 'Товар Ozon',
          price: parseInt(priceText) || 0,
          imageUrl: imageUrl,
          rating: rating,
          salesCount: salesCount,
          deepLink: link,
          marketplace: 'ozon'
        };
      }
      
      function collectCards() {
        const cards = document.querySelectorAll('.tile-root');
        let newCount = 0;
        cards.forEach((card, index) => {
          const product = parseCard(card, products.length);
          if (product) {
            products.push(product);
            newCount++;
          }
        });
        return { total: cards.length, newFound: newCount };
      }
      
      // ШАГ 1: Собираем начальные карточки
      let result = collectCards();
      console.log('Ozon: Initial - ' + result.total + ' cards, ' + result.newFound + ' new');
      
      // ШАГ 2: Скроллим и собираем 15 раз
      let noNewCount = 0;
      for (let i = 0; i < 15; i++) {
        window.scrollBy(0, 1000);
        await new Promise(r => setTimeout(r, 800));
        
        result = collectCards();
        console.log('Ozon: Scroll ' + (i+1) + '/15 - ' + result.total + ' cards, ' + result.newFound + ' new');
        
        if (result.newFound === 0) {
          noNewCount++;
          if (noNewCount >= 3) {
            console.log('Ozon: No new cards for 3 scrolls, stopping');
            break;
          }
        } else {
          noNewCount = 0;
        }
      }
      
      console.log('Ozon: Total parsed ' + products.length + ' products');
      
      // 🆕 ШАГ 3: Отправляем результат через канал Flutter
      const jsonResult = JSON.stringify(products);
      console.log('Ozon: Sending result to Flutter (' + jsonResult.length + ' chars)');
      
      if (window.flutter_ozon_result) {
        window.flutter_ozon_result.postMessage(jsonResult);
      } else {
        console.error('Ozon: flutter_ozon_result channel not found!');
      }
    })();
  ''';

  // ==================== МЕГАМАРКЕТ ====================
  
  static const String megamarketJsonInterceptor = '''
    (function() {
      const originalFetch = window.fetch;
      const originalXHR = window.XMLHttpRequest;
      
      window.fetch = function(...args) {
        const url = args[0] || '';
        return originalFetch.apply(this, args).then(response => {
          if ((url.includes('/api/') || url.includes('catalog') || url.includes('search')) 
              && url.includes('megamarket.ru')) {
            response.clone().json().then(data => {
              if (window.flutter_megamarket_handler) {
                window.flutter_megamarket_handler.postMessage(JSON.stringify(data));
              }
            }).catch(e => {});
          }
          return response;
        });
      };
      
      const originalOpen = originalXHR.prototype.open;
      const originalSend = originalXHR.prototype.send;
      
      originalXHR.prototype.open = function(method, url, ...rest) {
        this._url = url;
        return originalOpen.apply(this, [method, url, ...rest]);
      };
      
      originalXHR.prototype.send = function(...args) {
        this.addEventListener('load', function() {
          if (this._url && 
              (this._url.includes('/api/') || this._url.includes('catalog') || this._url.includes('search')) 
              && this._url.includes('megamarket.ru')) {
            try {
              const data = JSON.parse(this.responseText);
              if (window.flutter_megamarket_handler) {
                window.flutter_megamarket_handler.postMessage(JSON.stringify(data));
              }
            } catch(e) {}
          }
        });
        return originalSend.apply(this, args);
      };
      
      console.log('Megamarket JSON interceptor installed');
    })();
  ''';

  static const String megamarketSearchScript = '''
    (function() {
      const products = [];
      
      const selectors = [
        '.product-item',
        '.catalog-product-card',
        '[data-widget="catalogProducts"] [class*="product"]',
        'a[href*="/catalog/"][href*="-"]'
      ];
      
      let cards = [];
      for (const selector of selectors) {
        cards = document.querySelectorAll(selector);
        if (cards.length > 0) break;
      }
      
      cards.forEach((card, index) => {
        if (index > 15) return;
        
        let link = '';
        const linkEl = card.tagName === 'A' ? card : card.querySelector('a[href]');
        if (linkEl) {
          link = linkEl.href || '';
          if (link && !link.startsWith('http')) {
            link = 'https://megamarket.ru' + link;
          }
        }
        
        if (!link || !link.includes('/catalog/')) return;
        
        let priceEl = card.querySelector('[class*="price"], .product-price, [data-price]');
        if (!priceEl) {
          const allSpans = card.querySelectorAll('span');
          for (let el of allSpans) {
            const text = el.innerText;
            if ((text.includes('₽') || text.includes('руб')) && text.match(/\\d/)) {
              priceEl = el;
              break;
            }
          }
        }
        const priceText = priceEl ? priceEl.innerText.replace(/[^0-9]/g, '') : '0';
        
        let rating = 0;
        const ratingEl = card.querySelector('[class*="rating"], [class*="stars"]');
        if (ratingEl) {
          const match = ratingEl.innerText.match(/(\\d[.,]\\d)/);
          if (match) rating = parseFloat(match[1].replace(',', '.'));
        }
        
        let salesCount = 0;
        const cardText = card.innerText;
        const salesMatch = cardText.match(/отзывов?:?\\s*(\\d+)/i) || 
                           cardText.match(/(\\d+)\\s*отзыв/i);
        if (salesMatch) {
          salesCount = parseInt(salesMatch[1].replace(/[^0-9]/g, ''));
        }
        
        const imgEl = card.querySelector('img');
        const imageUrl = imgEl ? (imgEl.src || imgEl.getAttribute('data-src') || '') : '';
        
        let titleEl = card.querySelector('[class*="title"], [class*="name"], h3, h4');
        const name = titleEl ? titleEl.innerText.trim() : '';

        if (priceText && priceText !== '0' && name) {
          products.push({
            id: 'mm_' + index + '_' + Date.now(),
            name: name,
            price: parseInt(priceText),
            imageUrl: imageUrl,
            rating: rating,
            salesCount: salesCount,
            deepLink: link,
            marketplace: 'megamarket'
          });
        }
      });
      
      return JSON.stringify(products);
    })();
  ''';

  // ==================== WILDBERRIES ====================
  
  static const String wbJsonInterceptor = '''
    (function() {
      const originalFetch = window.fetch;
      window.fetch = function(...args) {
        const url = args[0] || '';
        return originalFetch.apply(this, args).then(response => {
          if (url.includes('/search') && url.includes('wb.ru')) {
            response.clone().json().then(data => {
              if (window.flutter_wb_handler) {
                window.flutter_wb_handler.postMessage(JSON.stringify(data));
              }
            }).catch(e => {});
          }
          return response;
        });
      };
      console.log('WB JSON interceptor installed');
    })();
  ''';

  static const String wbSearchScript = '''
    (function() {
      const products = [];
      const cards = document.querySelectorAll('[data-nm-id], .search-item, a[href*="/catalog/"]');
      
      cards.forEach((card, index) => {
        if (index > 15) return;
        
        let priceEl = card.querySelector('[class*="price__lower-price"], [class*="price__current"], .price-block__final-price');
        if (!priceEl) {
          const allSpans = card.querySelectorAll('span, div');
          for (let el of allSpans) {
            if (el.innerText.includes('₽') && el.innerText.match(/\\d/)) {
              priceEl = el;
              break;
            }
          }
        }
        const priceText = priceEl ? priceEl.innerText.replace(/[^0-9]/g, '') : '0';
        
        let rating = 0;
        const ratingEl = card.querySelector('[class*="rating"], [class*="stars"]');
        if (ratingEl) {
          const match = ratingEl.innerText.match(/(\\d[.,]\\d)/);
          if (match) rating = parseFloat(match[1].replace(',', '.'));
        }
        
        let salesCount = 0;
        const cardText = card.innerText;
        const salesMatch = cardText.match(/купили\\s+(\\d+)/i);
        if (salesMatch) {
          salesCount = parseInt(salesMatch[1].replace(/[^0-9]/g, ''));
        }
        
        const imgEl = card.querySelector('img');
        const titleEl = card.querySelector('[class*="name"], [class*="title"]');
        
        let link = card.href || '';
        if (!link.startsWith('http')) link = 'https://www.wildberries.ru' + link;

        if (priceText && priceText !== '0') {
          products.push({
            id: 'wb_' + index + '_' + Date.now(),
            name: titleEl ? titleEl.innerText.trim() : 'Товар WB',
            price: parseInt(priceText),
            imageUrl: imgEl ? (imgEl.src.startsWith('http') ? imgEl.src : 'https:' + imgEl.src) : '',
            rating: rating,
            salesCount: salesCount,
            deepLink: link,
            marketplace: 'wildberries'
          });
        }
      });
      return JSON.stringify(products);
    })();
  ''';
}