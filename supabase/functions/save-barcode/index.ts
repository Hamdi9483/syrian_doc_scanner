import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// 1. تعريف ترويسات CORS الموحدة
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// 2. استخدام Deno.serve الحديثة والمستقرة
Deno.serve(async (req) => {
  // التعامل مع طلبات Preflight (OPTIONS)
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // قراءة البيانات المرسلة من التطبيق
    const { raw_content, barcode_format } = await req.json()

    if (!raw_content) {
      return new Response(
        JSON.stringify({ error: "لم يتم تمرير نص المسح" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // الاتصال بقاعدة البيانات باستخدام المتغيرات البيئية
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey)

    // إدخال البيانات في الجدول
    const { data, error } = await supabaseAdmin
      .from('scanned_barcodes')
      .insert([
        { 
          raw_content: raw_content, 
          barcode_format: barcode_format ?? 'UNKNOWN',
          device_info: 'Syrian Doc Scanner Mobile'
        }
      ])

    if (error) {
      throw error
    }

    // إرجاع استجابة النجاح
    return new Response(
      JSON.stringify({ message: "تم التخزين بأمان بنجاح" }),
      { 
        status: 200, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    )

  } catch (error) {
    // إرجاع الخطأ مع ترويسات CORS لكي يظهر في التطبيق بوضوح
    return new Response(
      JSON.stringify({ error: error.message }),
      { 
        status: 500, 
        headers: { ...corsHeaders, "Content-Type": "application/json" } 
      }
    )
  }
})