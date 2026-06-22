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

  static const String ozonSearchScript = '''
    (function() {
      const products = [];
      const cards = document.querySelectorAll('[data-widget="searchResultsV2"] a.tile-root, [class*="tile-root"]');
      
      cards.forEach((card, index) => {
        if (index > 15) return;
        
        let link = '';
        if (card.tagName === 'A') {
          link = card.href || '';
        } else {
          const linkEl = card.querySelector('a[href]');
          if (linkEl) link = linkEl.href || '';
        }
        
        if (link && !link.startsWith('http')) {
          link = 'https://www.ozon.ru' + link;
        }
        
        if (!link || link === 'https://www.ozon.ru/' || link === 'https://www.ozon.ru') {
          return;
        }
        
        let priceEl = card.querySelector('[class*="price__current-price"], [class*="price__price"], span[class*="price"]');
        if (!priceEl) {
          const allSpans = card.querySelectorAll('span');
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
        const salesMatch = cardText.match(/купили\\s+(\\d+)/i) || 
                           cardText.match(/(\\d+)\\+?\\s*покупок/i);
        if (salesMatch) {
          salesCount = parseInt(salesMatch[1].replace(/[^0-9]/g, ''));
        }
        
        const imgEl = card.querySelector('img');
        const titleEl = card.querySelector('[class*="title"], [class*="name"]');

        if (priceText && priceText !== '0') {
          products.push({
            id: 'ozon_' + index + '_' + Date.now(),
            name: titleEl ? titleEl.innerText.trim() : 'Товар Ozon',
            price: parseInt(priceText),
            imageUrl: imgEl ? imgEl.src : '',
            rating: rating,
            salesCount: salesCount,
            deepLink: link,
            marketplace: 'ozon'
          });
        }
      });
      return JSON.stringify(products);
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
          // Ловим API запросы Мегамаркета
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
      
      // Ищем карточки товаров на Мегамаркете
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
        
        // Ссылка
        let link = '';
        const linkEl = card.tagName === 'A' ? card : card.querySelector('a[href]');
        if (linkEl) {
          link = linkEl.href || '';
          if (link && !link.startsWith('http')) {
            link = 'https://megamarket.ru' + link;
          }
        }
        
        if (!link || !link.includes('/catalog/')) return;
        
        // Цена
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
        
        // Рейтинг
        let rating = 0;
        const ratingEl = card.querySelector('[class*="rating"], [class*="stars"]');
        if (ratingEl) {
          const match = ratingEl.innerText.match(/(\\d[.,]\\d)/);
          if (match) rating = parseFloat(match[1].replace(',', '.'));
        }
        
        // Продажи
        let salesCount = 0;
        const cardText = card.innerText;
        const salesMatch = cardText.match(/отзывов?:?\\s*(\\d+)/i) || 
                           cardText.match(/(\\d+)\\s*отзыв/i);
        if (salesMatch) {
          salesCount = parseInt(salesMatch[1].replace(/[^0-9]/g, ''));
        }
        
        // Картинка
        const imgEl = card.querySelector('img');
        const imageUrl = imgEl ? (imgEl.src || imgEl.getAttribute('data-src') || '') : '';
        
        // Название
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