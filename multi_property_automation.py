# multi_property_automation.py - 다중 매물 처리

import asyncio
import os
import sys
from datetime import datetime
from playwright.async_api import async_playwright

class MultiPropertyAutomation:
    def __init__(self):
        self.login_id = os.getenv('LOGIN_ID', 'keunmun')
        self.login_pw = os.getenv('LOGIN_PASSWORD', 'tjsrb1234!')
        self.login_url = "https://www.aipartner.com/integrated/login?serviceCode=1000"
        self.ad_list_url = "https://www.aipartner.com/offerings/ad_list"
        
        # 환경변수에서 매물번호들 가져오기
        property_numbers_str = os.getenv('PROPERTY_NUMBERS', '')
        self.property_numbers = [
            num.strip() for num in property_numbers_str.split(',') 
            if num.strip()
        ]
        
        self.test_mode = os.getenv('TEST_MODE', 'false').lower() == 'true'
        
        print(f"🔧 로그인 ID: {self.login_id}")
        print(f"🏠 처리할 매물: {len(self.property_numbers)}개")
        print(f"📋 매물번호: {', '.join(self.property_numbers)}")
        print(f"🧪 테스트 모드: {self.test_mode}")
    
    async def login(self, page):
        """로그인 처리"""
        print("🔗 로그인 페이지로 이동 중...")
        
        await page.goto(self.login_url, timeout=60000)
        await page.wait_for_selector('#member-id', timeout=30000)
        
        await page.fill('#member-id', self.login_id)
        await page.fill('#member-pw', self.login_pw)
        await page.click('#integrated-login > a')
        
        await page.wait_for_timeout(10000)
        
        # 로그인 성공 확인
        current_url = page.url
        title = await page.title()
        
        print(f"🔗 로그인 후 URL: {current_url}")
        print(f"📄 로그인 후 제목: {title}")
        
        is_login_page = any([
            'login' in current_url.lower(),
            '로그인' in title,
            await page.query_selector('#member-id')
        ])
        
        if is_login_page:
            print("❌ 로그인 실패")
            return False
        
        print("✅ 로그인 완료")
        return True
    
    async def process_single_property(self, page, property_number, index, total, retry=False):
        """단일 매물 처리 (페이지네이션 포함)"""
        retry_text = " (재시도)" if retry else ""
        print(f"\n{'='*60}")
        print(f"[{index}/{total}] 매물번호 {property_number} 처리 시작{retry_text}")
        print(f"{'='*60}")
        
        # 재시도인 경우 추가 대기
        if retry:
            print("🔄 재시도 모드: 안정성을 위해 추가 대기...")
            await page.wait_for_timeout(3000)
        
        # 페이지 로드 시 팝업 처리를 위한 전역 핸들러
        page_load_popup_handled = False
        async def handle_page_load_popup(dialog):
            nonlocal page_load_popup_handled
            print(f"🚨 페이지 로드 중 팝업 감지!")
            print(f"   타입: {dialog.type}")
            print(f"   메시지: '{dialog.message}'")

            try:
                await dialog.accept()
                page_load_popup_handled = True
                print("✅ 페이지 로드 팝업 확인 완료")
            except Exception as e:
                print(f"❌ 페이지 로드 팝업 처리 중 오류: {e}")
                try:
                    await dialog.dismiss()
                    print("🔄 페이지 로드 팝업 취소로 처리")
                except:
                    print("❌ 페이지 로드 팝업 처리 실패")

        # 페이지 로드 팝업 리스너 등록
        page.on('dialog', handle_page_load_popup)
        
        # 이미지 팝업 오버레이 처리 함수
        async def handle_popup_overlay():
            """DOM 기반 팝업 오버레이 처리"""
            try:
                # 팝업 이미지를 찾고 닫기 버튼 찾기
                popup_selectors = [
                    'img[src*="popup"]',
                    'div[class*="popup"]',
                    'div[id*="popup"]',
                    '.modal',
                    '.overlay'
                ]
                
                for selector in popup_selectors:
                    popup_elements = await page.query_selector_all(selector)
                    if popup_elements:
                        print(f"🚨 {selector} 팝업 오버레이 감지 ({len(popup_elements)}개)")
                        
                        # 닫기 버튼 찾기 시도
                        close_selectors = [
                            'button[class*="close"]',
                            'button[class*="dismiss"]',
                            'span[class*="close"]',
                            'div[class*="close"]',
                            'a[class*="close"]',
                            '.close',
                            '.dismiss',
                            '.x-button'
                        ]
                        
                        popup_closed = False
                        for close_selector in close_selectors:
                            try:
                                close_button = await page.query_selector(close_selector)
                                if close_button:
                                    await close_button.click()
                                    print(f"✅ {close_selector} 닫기 버튼 클릭 성공")
                                    popup_closed = True
                                    break
                            except Exception as e:
                                continue
                        
                        # 닫기 버튼을 찾지 못한 경우 ESC 키 시도
                        if not popup_closed:
                            try:
                                await page.keyboard.press('Escape')
                                print("✅ ESC 키로 팝업 닫기 시도")
                                popup_closed = True
                            except:
                                pass
                        
                        # 팝업 오버레이를 직접 숨기기 시도
                        if not popup_closed:
                            try:
                                await page.evaluate('''
                                    () => {
                                        // 모든 팝업 오버레이 숨기기
                                        const popups = document.querySelectorAll('img[src*="popup"], div[class*="popup"], div[id*="popup"], .modal, .overlay');
                                        popups.forEach(popup => {
                                            popup.style.display = 'none';
                                            popup.style.visibility = 'hidden';
                                            popup.remove();
                                        });
                                        
                                        // z-index가 높은 요소들도 제거
                                        const highZIndexElements = document.querySelectorAll('*');
                                        highZIndexElements.forEach(el => {
                                            const zIndex = window.getComputedStyle(el).zIndex;
                                            if (zIndex && parseInt(zIndex) > 1000) {
                                                el.style.display = 'none';
                                                el.remove();
                                            }
                                        });
                                    }
                                ''')
                                print("✅ JavaScript로 팝업 오버레이 제거 완료")
                            except Exception as e:
                                print(f"⚠️ JavaScript 팝업 제거 실패: {e}")
                        
                        await page.wait_for_timeout(1000)
                        break
                        
            except Exception as e:
                print(f"⚠️ 팝업 오버레이 처리 중 오류: {e}")
        
        try:
            print("🌐 매물 리스트 페이지로 이동 중...")
            await page.goto(self.ad_list_url, timeout=60000)
            
            # 페이지 로드 후 팝업 처리 대기
            await page.wait_for_timeout(3000)
            
            # 팝업 오버레이 처리
            await handle_popup_overlay()
            
            if page_load_popup_handled:
                print("✅ 페이지 로드 팝업 처리됨")
            
            print("📋 매물 테이블 로딩 대기 중...")
            await page.wait_for_selector('table tbody tr', timeout=30000)
            
            # 매물 검색 (페이지네이션 포함)
            property_found = False
            current_page = 1
            max_pages = 10
            
            while not property_found and current_page <= max_pages:
                print(f"📄 {current_page}페이지에서 매물 검색 중...")
                
                # 테이블 찾기
                await page.wait_for_selector('table tbody tr', timeout=30000)
                rows = await page.query_selector_all('table tbody tr')
                
                print(f"📊 {current_page}페이지 매물 수: {len(rows)}개")
                
                # 현재 페이지에서 매물 검색
                for i, row in enumerate(rows, 1):
                    try:
                        # 매물번호가 있는 셀 찾기 (더 정확한 방법)
                        number_cell = await row.query_selector('td:nth-child(3) > div.numberN')
                        if number_cell:
                            number_text = await number_cell.inner_text()
                            if property_number in number_text.strip():
                                print(f"🎯 매물번호 {property_number} 발견! ({current_page}페이지, 행 {i})")
                                
                                # 매물 정보 출력
                                await self.print_property_info(row, property_number)
                                
                                # 업데이트 실행
                                if self.test_mode:
                                    await self.simulate_update(property_number)
                                else:
                                    await self.execute_real_update(page, row, property_number)
                                
                                property_found = True
                                break
                    except Exception as e:
                        print(f"⚠️ 행 {i} 처리 중 오류: {e}")
                        continue
                
                if property_found:
                    break
                
                # 다음 페이지로 이동
                try:
                    next_button = await page.query_selector('#wrap > div > div > div > div.sectionWrap > div.singleSection.listSection > div.pagination > span:nth-child(5) > a')
                    if next_button:
                        button_class = await next_button.get_attribute('class')
                        if button_class and 'disabled' in button_class:
                            print("마지막 페이지에 도달했습니다.")
                            break

                        # 페이지네이션 팝업 처리 준비
                        pagination_popup_handled = False
                        async def handle_pagination_popup(dialog):
                            nonlocal pagination_popup_handled
                            print(f"🚨 페이지네이션 중 팝업 감지!")
                            print(f"   타입: {dialog.type}")
                            print(f"   메시지: '{dialog.message}'")

                            try:
                                await dialog.accept()
                                pagination_popup_handled = True
                                print("✅ 페이지네이션 팝업 확인 완료")
                            except Exception as e:
                                print(f"❌ 페이지네이션 팝업 처리 중 오류: {e}")
                                try:
                                    await dialog.dismiss()
                                    print("🔄 페이지네이션 팝업 취소로 처리")
                                except:
                                    print("❌ 페이지네이션 팝업 처리 실패")

                        # 기존 리스너 제거 후 새 리스너 등록
                        page.remove_listener('dialog', handle_page_load_popup)
                        page.on('dialog', handle_pagination_popup)

                        print(f"📄 {current_page+1}페이지로 이동 중...")
                        await next_button.click()

                        # 페이지네이션 후 팝업 처리 및 로딩 대기
                        await page.wait_for_timeout(5000)  # 더 긴 대기 시간

                        # 팝업 오버레이 처리
                        await handle_popup_overlay()

                        if pagination_popup_handled:
                            print("✅ 페이지네이션 팝업 처리됨")

                        # 새 페이지 로딩 대기
                        try:
                            await page.wait_for_selector('table tbody tr', timeout=15000)
                            print(f"✅ {current_page+1}페이지 로딩 완료")
                        except:
                            print(f"⚠️ {current_page+1}페이지 로딩 실패 - 계속 진행")

                        current_page += 1

                        # 페이지네이션 리스너 제거 후 원래 리스너 복원
                        page.remove_listener('dialog', handle_pagination_popup)
                        page.on('dialog', handle_page_load_popup)

                    else:
                        print("다음 페이지 버튼을 찾을 수 없습니다.")
                        break
                except Exception as e:
                    print(f"페이지 이동 중 오류: {e}")
                    # 오류 시 스크린샷 저장
                    try:
                        await page.screenshot(path=f"pagination_error_{property_number}_{current_page}.png")
                        print(f"페이지네이션 오류 스크린샷 저장됨")
                    except:
                        pass
                    break
            
            if not property_found:
                print(f"❌ 매물번호 {property_number}를 {current_page-1}페이지까지 검색했지만 찾을 수 없습니다.")
                return False
            
            print(f"✅ 매물번호 {property_number} 처리 완료")
            return True
            
        except Exception as e:
            print(f"❌ 매물번호 {property_number} 처리 실패: {e}")
            return False
        finally:
            # 페이지 로드 팝업 리스너 정리
            try:
                page.remove_listener('dialog', handle_page_load_popup)
                print("🧹 페이지 로드 팝업 리스너 정리 완료")
            except:
                pass
    
    async def print_property_info(self, row, property_number):
        """매물 정보 출력"""
        try:
            cells = await row.query_selector_all('td')
            if len(cells) >= 6:
                name = await cells[1].inner_text() if len(cells) > 1 else "알 수 없음"
                trade_type = await cells[3].inner_text() if len(cells) > 3 else "알 수 없음"
                price = await cells[4].inner_text() if len(cells) > 4 else "알 수 없음"
                
                print(f"📋 매물 정보:")
                print(f"   번호: {property_number}")
                print(f"   매물명: {name.strip()}")
                print(f"   거래종류: {trade_type.strip()}")
                print(f"   가격: {price.strip()}")
        except Exception as e:
            print(f"⚠️ 매물 정보 추출 중 오류: {e}")
    
    async def simulate_update(self, property_number):
        """업데이트 시뮬레이션"""
        print(f"\n🧪 매물번호 {property_number} 업데이트 시뮬레이션:")
        print("1️⃣ 노출종료 (시뮬레이션)")
        await asyncio.sleep(1)
        print("2️⃣ 광고종료 (시뮬레이션)")
        await asyncio.sleep(1)
        print("3️⃣ 재광고 (시뮬레이션)")
        await asyncio.sleep(1)
        print("4️⃣ 광고등록 (시뮬레이션)")
        await asyncio.sleep(1)
        print("5️⃣ 결제완료 (시뮬레이션)")
        print(f"🎉 매물번호 {property_number} 시뮬레이션 완료!")
    
    async def execute_real_update(self, page, row, property_number):
        """실제 업데이트 실행"""
        print(f"\n🚀 매물번호 {property_number} 실제 업데이트:")
        
        try:
            # 1. 노출종료
            print("1️⃣ 노출종료 버튼 클릭...")
            end_button = await row.query_selector('#naverEnd')
            if not end_button:
                print("❌ 노출종료 버튼을 찾을 수 없습니다.")
                return False
            
            # 팝업 처리를 위한 이벤트 리스너 등록
            popup_handled = False
            async def handle_popup(dialog):
                nonlocal popup_handled
                print(f"🚨 팝업 감지!")
                print(f"   타입: {dialog.type}")
                print(f"   메시지: '{dialog.message}'")

                try:
                    await dialog.accept()
                    popup_handled = True
                    print("✅ 팝업 확인 버튼 클릭 완료")
                except Exception as e:
                    print(f"❌ 팝업 처리 중 오류: {e}")
                    try:
                        await dialog.dismiss()
                        print("🔄 팝업 취소 버튼으로 처리")
                    except:
                        print("❌ 팝업 처리 실패")

            page.on('dialog', handle_popup)

            # 팝업 오버레이 처리 함수 (공통 사용)
            async def handle_popup_overlay():
                """DOM 기반 팝업 오버레이 처리"""
                try:
                    await page.evaluate('''
                        () => {
                            // 모든 팝업 오버레이 숨기기
                            const popups = document.querySelectorAll('img[src*="popup"], div[class*="popup"], div[id*="popup"], .modal, .overlay');
                            popups.forEach(popup => {
                                popup.style.display = 'none';
                                popup.style.visibility = 'hidden';
                                popup.remove();
                            });
                            
                            // z-index가 높은 요소들도 제거
                            const highZIndexElements = document.querySelectorAll('*');
                            highZIndexElements.forEach(el => {
                                const zIndex = window.getComputedStyle(el).zIndex;
                                if (zIndex && parseInt(zIndex) > 1000) {
                                    el.style.display = 'none';
                                    el.remove();
                                }
                            });
                        }
                    ''')
                    print("✅ JavaScript로 팝업 오버레이 제거 완료")
                except Exception as e:
                    print(f"⚠️ JavaScript 팝업 제거 실패: {e}")

            try:
                # 팝업 오버레이 사전 제거
                await handle_popup_overlay()
                
                # 노출종료 버튼 클릭
                print("🖱️ 노출종료 버튼을 클릭합니다...")
                await end_button.click(force=True)  # force 옵션 추가
                print("✅ 노출종료 버튼 클릭 완룼")

                # 팝업이 나타날 시간을 기다림 (더 긴 대기 시간)
                print("⏳ 팝업 확인을 위해 대기 중...")
                await page.wait_for_timeout(5000)  # 5초로 증가

                if popup_handled:
                    print("✅ 팝업 처리 완료됨")
                else:
                    print("ℹ️ 팝업이 나타나지 않았거나 이미 처리됨")
                    
                print("   ✅ 노출종료 완료")

            except Exception as e:
                print(f"노출종료 버튼 클릭 중 오류: {e}")
                # 스크린샷 저장 (디버깅용)
                try:
                    await page.screenshot(path=f"error_screenshot_{property_number}_end_button.png")
                    print(f"오류 스크린샷 저장됨: error_screenshot_{property_number}_end_button.png")
                except:
                    pass
                return False
            finally:
                # 이벤트 리스너 제거
                page.remove_listener('dialog', handle_popup)
            
            # 2. 광고종료
            print("2️⃣ 광고종료 버튼 클릭...")
            ad_end_button = await page.wait_for_selector('.statusAdEnd', timeout=10000)
            await ad_end_button.click()
            await page.wait_for_timeout(3000)
            print("   ✅ 종료매물 목록 표시")
            
            # 3. 재광고
            print("3️⃣ 종료매물에서 재광고 버튼 검색...")
            end_rows = await page.query_selector_all('table tbody tr')
            
            for row in end_rows:
                number_cell = await row.query_selector('td:nth-child(3) > div.numberN')
                if number_cell:
                    number_text = await number_cell.inner_text()
                    if property_number in number_text.strip():
                        re_ad_button = await row.query_selector('#reReg')
                        if re_ad_button:
                            await re_ad_button.click()
                            await page.wait_for_timeout(3000)
                            print("   ✅ 재광고 버튼 클릭 완료")
                            break
            
            # 4. 광고등록
            print("4️⃣ 광고등록 페이지 처리...")
            await page.wait_for_url('**/offerings/ad_regist', timeout=30000)
            await page.wait_for_timeout(2000)
            
            await page.click('text=광고하기')
            await page.wait_for_timeout(2000)
            print("   ✅ 광고하기 버튼 클릭 완료")
            
            # 5. 결제
            print("5️⃣ 결제 처리...")
            await page.wait_for_timeout(3000)

            await page.evaluate("document.querySelector('#consentMobile2').click()")
            await page.wait_for_timeout(1000)
            print("   ✅ 체크박스 클릭 완료")
                        
            payment_button = await page.query_selector('#naverSendSave')
            if payment_button:
                await payment_button.click()
                print("   ✅ 결제하기 버튼 클릭 완료")
            
            await page.wait_for_timeout(3000)
            print(f"🎉 매물번호 {property_number} 실제 업데이트 완료!")
            
            return True
            
        except Exception as e:
            print(f"❌ 실제 업데이트 중 오류: {e}")
            return False
    
    async def run_automation(self):
        """다중 매물 자동화 실행"""
        print("\n" + "="*80)
        print(f"🚀 다중 매물 자동화 시작 - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("="*80)
        
        if not self.property_numbers:
            print("❌ 처리할 매물번호가 없습니다.")
            return
        
        async with async_playwright() as p:
            try:
                # GitHub Actions에서는 항상 headless 모드로 실행
                browser = await p.chromium.launch(
                    headless=True,
                    slow_mo=500,  # 빠른 실행
                    args=[
                        '--disable-blink-features=AutomationControlled',
                        '--no-sandbox',
                        '--disable-setuid-sandbox',
                        '--disable-dev-shm-usage',
                        '--disable-accelerated-2d-canvas',
                        '--no-first-run',
                        '--no-zygote',
                        '--disable-gpu',
                        '--disable-web-security'
                    ]
                )
                
                context = await browser.new_context(
                    viewport={'width': 1280, 'height': 720},
                    user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                )
                
                page = await context.new_page()
                
                # 전역 팝업 처리 함수
                async def handle_global_popup(dialog):
                    print(f"전역 팝업 감지: {dialog.type} - {dialog.message}")
                    try:
                        if dialog.type == 'alert':
                            await dialog.accept()
                            print("Alert 팝업 확인됨")
                        elif dialog.type == 'confirm':
                            await dialog.accept()  # 확인 선택
                            print("Confirm 팝업 확인됨")
                        elif dialog.type == 'prompt':
                            await dialog.accept("")  # 빈 값으로 확인
                            print("Prompt 팝업 확인됨")
                    except Exception as e:
                        print(f"팝업 처리 중 오류: {e}")

                # 전역 팝업 이벤트 리스너 등록
                page.on('dialog', handle_global_popup)
                
                # 로그인
                login_success = await self.login(page)
                if not login_success:
                    print("❌ 로그인 실패로 자동화 중단")
                    return
                
                # 각 매물 순차 처리
                success_count = 0
                failed_properties = []
                retry_failed = []  # 전역 변수로 선언

                for i, property_number in enumerate(self.property_numbers, 1):
                    success = await self.process_single_property(page, property_number, i, len(self.property_numbers))
                    
                    if success:
                        success_count += 1
                    else:
                        failed_properties.append(property_number)
                    
                    # 매물 간 대기
                    if i < len(self.property_numbers):
                        print(f"⏳ 다음 매물 처리까지 5초 대기...")
                        await page.wait_for_timeout(5000)

                # 🔄 실패한 매물 재시도 로직 추가
                if failed_properties:
                    print(f"\n🔄 실패한 {len(failed_properties)}개 매물 재시도 중...")
                    print("="*60)
                    
                    # retry_failed 이미 전역 변수로 선언됨
                    for i, property_number in enumerate(failed_properties, 1):
                        print(f"\n[재시도 {i}/{len(failed_properties)}] 매물번호 {property_number}")
                        success = await self.process_single_property(page, property_number, i, len(failed_properties), retry=True)
                        
                        if success:
                            success_count += 1
                            print(f"✅ 재시도 성공: {property_number}")
                        else:
                            retry_failed.append(property_number)
                            print(f"❌ 재시도 실패: {property_number}")
                        
                        # 재시도 간 대기
                        if i < len(failed_properties):
                            await page.wait_for_timeout(3000)

                # 최종 결과
                print("\n" + "="*80)
                print("📊 다중 매물 자동화 완료!")
                print(f"✅ 최종 성공: {success_count}/{len(self.property_numbers)}개")
                if retry_failed:
                    print(f"❌ 최종 실패: {', '.join(retry_failed)}")
                else:
                    print("🎉 모든 매물 처리 완료!")
                print("="*80)
                
                # 최종 스크린샷
                screenshot_path = f"multi_automation_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
                await page.screenshot(path=screenshot_path)
                print(f"📸 최종 스크린샷: {screenshot_path}")
                
                await browser.close()
                
            except Exception as e:
                print(f"❌ 자동화 실행 실패: {e}")
                try:
                    await browser.close()
                except:
                    pass

async def main():
    automation = MultiPropertyAutomation()
    await automation.run_automation()

if __name__ == "__main__":
    asyncio.run(main())
