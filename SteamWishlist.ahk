#NoEnv
#SingleInstance, force
SetWorkingDir %A_ScriptDir%

if (A_PtrSize = 8)
	throw "Please run in 32-bit AutoHotkey"

global oWishlistData, hListBox, hAdapter

global xc := new lazyCall("XCGUI.dll")

xc.XInitXCGUI()
InitWindow()
xc.XRunXCGUI()
xc.XExitXCGUI()
return

InitWindow() {
	xc.XC_LoadResource("ui\resource.res")
	xc.XC_LoadStyle("ui\style.css")
	m_hWindow := xc.XC_LoadLayout("ui\main.xml")
	if (xc.XC_IsHWINDOW(m_hWindow)) {
		InitListBox()
		xc.XWnd_AdjustLayout(m_hWindow)
		xc.XWnd_ShowWindow(m_hWindow, SW_SHOW:=5)
	}
}

InitListBox() {
	hListBox := xc.XC_GetObjectByName("listbox1")

	hSBV := xc.XSView_GetScrollBarV(hListBox)
	xc.XSBar_ShowButton(hSBV, false)

	xc.XListBox_SetItemTemplateXML(hListBox, "ui\EXPANDED.xml")
	xc.XListBox_SetItemHeightDefault(hListBox, 187, 187)
	xc.XListBox_SetRowSpace(hListBox, 0)
	xc.XListBox_SetDrawItemBkFlags(hListBox, list_drawItemBk_flags_nothing:=0x000)

	InitListBox_LoadData()

	xc.XEle_RegEventC2(hListBox, XE_LISTBOX_TEMP_CREATE_END:=82, RegisterCallback("OnListBoxTemplateCreateEnd","F"))
}

InitListBox_LoadData() {
	hAdapter := xc.XListBox_CreateAdapter(hListBox)
	xc.XAdTable_AddColumn(hAdapter, "capsule")
	xc.XAdTable_AddColumn(hAdapter, "appId")
	iColumnAdapter_price := xc.XAdTable_AddColumn(hAdapter, "price")

	FileRead, json, wishlistdata\wishlistdata.json
	oWishlistData := Jxon_Load(json)

	hImage_mac   := xc.XRes_GetImage("icon_platform_mac.png")
	hImage_linux := xc.XRes_GetImage("icon_platform_linux.png")

	for appId, item in oWishlistData
	{
		hImage := xc.XImage_LoadFile("wishlistdata\" appId ".jpg", true)
		iItem  := xc.XListBox_AddItemImageEx(hListBox, "capsule", hImage)

		xc.XAdTable_SetItemTextEx(hAdapter, iItem, "appId", appId "/")

		for i, k in ["mac", "linux"] {
			if item[k]
				xc.XListBox_SetItemImageEx(hListBox, iItem, "platform_icon" (i+1), hImage_%k%)
		}

		xc.XListBox_SetItemTextEx(hListBox, iItem, "title"       , item.name)
		xc.XListBox_SetItemTextEx(hListBox, iItem, "review_desc" , Uppercase(item.review_desc))
		xc.XListBox_SetItemTextEx(hListBox, iItem, "release_date", Uppercase(item.release_string))
		xc.XListBox_SetItemTextEx(hListBox, iItem, "addedon"     , "Added on " FormatUnixTime(item.added) " (")
		xc.XListBox_SetItemIntEx(hListBox,  iItem, "price"       , Ceil(item.subs.1.price))

		btnText := (item.subs.MaxIndex() > 1) ? "View Details"
		         : (item.is_free_game)        ? "Play now"
		         : "Add to Cart"
		xc.XListBox_SetItemTextEx(hListBox, iItem, "main-btn", btnText)

		if RegExMatch(item.subs.1.discount_block, """discount_final_price"">\K[^<]+", discount_final_price)
			xc.XListBox_SetItemTextEx(hListBox, iItem, "discount_final_price", discount_final_price)

		if (pct := item.subs.1.discount_pct) {
			xc.XListBox_SetItemTextEx(hListBox, iItem, "discount_pct", "-" pct "%")
			if RegExMatch(item.subs.1.discount_block, """discount_original_price"">\K[^<]+", discount_original_price)
				xc.XListBox_SetItemTextEx(hListBox, iItem, "discount_original_price", discount_original_price)
		}
	}

	xc.XListBox_Sort(hListBox, iColumnAdapter_price, true)
}

Uppercase(str) {
	return Format("{:U}", str)
}

OnListBoxTemplateCreateEnd(hListBox, hEventEle, pItem, pbHandled) {
	iItem := NumGet(pItem+0, 0, "Int")

	ChangeReviewColor(iItem)
	ShowHide_discount_pct(iItem)
	ShowHide_price(iItem)

	hBtn := xc.XListBox_GetTemplateObject(hListBox, iItem, 100) ; capsule
	xc.XEle_RegEventC2(hBtn, XE_MOUSESTAY:=6, RegisterCallback("capsule_OnMouseStay","F"))

	hBtn := xc.XListBox_GetTemplateObject(hListBox, iItem, 200) ; Animation button
	xc.XEle_RegEventC2(hBtn, XE_BNCLICK:=34, RegisterCallback("GameTitle_OnClick","F"))
	xc.XEle_RegEventC2(hBtn, XE_MOUSELEAVE:=8, RegisterCallback("capsule_OnMouseLeave","F"))

	hBtn := xc.XListBox_GetTemplateObject(hListBox, iItem, 33)
	if isViewDetailsBtn(iItem) {
		xc.XEle_SetCssName(hBtn, "style_blueBtn")
		xc.XEle_SetTextColor(hBtn, 0xF5D7A4, 255)
	}
	xc.XEle_RegEventC2(hBtn, XE_BNCLICK:=34, RegisterCallback("AddToCart_OnClick","F"))
	xc.XEle_RegEventC2(hBtn, XE_MOUSESTAY:=6, RegisterCallback("AddToCart_OnMouseStay","F"))
	xc.XEle_RegEventC2(hBtn, XE_MOUSELEAVE:=8, RegisterCallback("AddToCart_OnMouseLeave","F"))

	hBtn := xc.XListBox_GetTemplateObject(hListBox, iItem, 44)
	xc.XEle_RegEventC2(hBtn, XE_BNCLICK:=34, RegisterCallback("Remove_OnClick","F"))

	hBtn := xc.XListBox_GetTemplateObject(hListBox, iItem, 66)
	xc.XEle_RegEventC2(hBtn, XE_BNCLICK:=34, RegisterCallback("GameTitle_OnClick","F"))
}

isViewDetailsBtn(iItem) {
	appId := GetAppidFromListbox(iItem)
	return oWishlistData[appId].subs.MaxIndex() > 1
}

ChangeReviewColor(iItem) {
	hTextBlock := xc.XListBox_GetTemplateObject(hListBox, iItem, 1) ; review_desc

	text := DllCall("XCGUI\XShapeText_GetText", "int", hTextBlock, "str")

	color := (text = "MIXED") ? 0x74A0B9
	       : (text = "NO USER REVIEWS") ? 0x929396
	       : (text ~= "POSITIVE") ? 0xF4C066
	       : 0xA34C25
	xc.XShapeText_SetTextColor(hTextBlock, color, 255)
}

ShowHide_discount_pct(iItem) {
	discount_pct := StrGet( xc.XAdTable_GetItemTextEx(hAdapter, iItem, "discount_pct") )
	if (!discount_pct) {
		hEle := xc.XListBox_GetTemplateObject(hListBox, iItem, 22)
		xc.XEle_Destroy(hEle)
	}
}

ShowHide_price(iItem) {
	appId := GetAppidFromListbox(iItem)
	if (oWishlistData[appId].is_free_game) {
		hEle := xc.XListBox_GetTemplateObject(hListBox, iItem, 23)
		xc.XEle_Destroy(hEle)
	}
}

AddToCart_OnClick(hEle, hEventEle, pbHandled) {
	iItem := xc.XListBox_GetItemIndexFromHXCGUI(hListBox, hEle)
	MsgBox, % "Row Index = " iItem
}

AddToCart_OnMouseStay(hEle, hEventEle, pbHandled) {
	xc.XEle_SetTextColor(hEle, 0xffffff, 255)
}

AddToCart_OnMouseLeave(hEle, hEventEle, hEleStay, pbHandled) {
	iItem := xc.XListBox_GetItemIndexFromHXCGUI(hListBox, hEle)
	color := isViewDetailsBtn(iItem) ? 0xF5D7A4 : 0x85E8D2
	xc.XEle_SetTextColor(hEle, color, 255)
}

AddAnimationFrame(hBtn, iItem) {
	appId := GetAppidFromListbox(iItem)

	for i, filename in oWishlistData[appId].screenshots {
		hImage := xc.XImage_LoadFile("wishlistdata\" filename, false)
		xc.XBtn_AddAnimationFrame(hBtn, hImage, 1000)
	}
}

capsule_OnMouseStay(hEle, hEventEle, pbHandled) {
	iItem := xc.XListBox_GetItemIndexFromHXCGUI(hListBox, hEle)
	hBtn  := xc.XListBox_GetTemplateObject(hListBox, iItem, 200) ; Animation button

	isAnimationAdded := xc.XEle_GetUserData(hEle)
	if (!isAnimationAdded) {
		AddAnimationFrame(hBtn, iItem)
		xc.XEle_SetUserData(hEle, 1)
	}

	xc.XEle_SetZOrder(hBtn, 1)
	xc.XBtn_EnableAnimation(hBtn, true, true)
}

capsule_OnMouseLeave(hEle, hEventEle, hEleStay, pbHandled) {
	xc.XEle_SetZOrder(hEle, 0)
	xc.XBtn_EnableAnimation(hEle, false, true)
}

Remove_OnClick(hEle, hEventEle, pbHandled) {
	iItem := xc.XListBox_GetItemIndexFromHXCGUI(hListBox, hEle)
	xc.XListBox_DeleteItem(hListBox, iItem)
	xc.XEle_RedrawEle(hListBox)
}

GameTitle_OnClick(hEle, hEventEle, pbHandled) {
	iItem := xc.XListBox_GetItemIndexFromHXCGUI(hListBox, hEle)
	Run, % "https://store.steampowered.com/app/" GetAppidFromListbox(iItem)
}

GetAppidFromListbox(iItem) {
	appId := StrGet( xc.XAdTable_GetItemTextEx(hAdapter, iItem, "appId") )
	return SubStr(appId, 1, -1)
}

FormatUnixTime(unixTimestamp) {
	unixTimestamp := SubStr(unixTimestamp, 1, 10)
	_date = 1970010108
	_date += unixTimestamp, s
	FormatTime, t, %_date%, yyyy/MM/dd
	return t
}

class LazyCall
{
	__New(DllFile) {
		this.hModule := DllCall("LoadLibrary", "Str", DllFile, "Ptr")
		this.dll := RegExReplace(DllFile, ".*\\")
	}

	__Delete() {
		DllCall("FreeLibrary", "Ptr", this.hModule)
	}

	__Call(FuncName, Params*) {
		p := []
		for i, v in Params
		{
			if v is Number
				p.push("int", v)
			else
				p.push("str", v)
		}
		return DllCall(this.dll "\" FuncName, p*)
	}
}
